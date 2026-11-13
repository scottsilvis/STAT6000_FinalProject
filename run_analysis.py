#!/usr/bin/env python3
"""Compare classification models using one ABIDE I study site."""

import argparse
import json
from pathlib import Path

import numpy as np
import pandas as pd
from scipy.io import loadmat
from sklearn.base import clone
from sklearn.decomposition import PCA
from sklearn.discriminant_analysis import LinearDiscriminantAnalysis
from sklearn.feature_selection import SelectKBest, f_classif
from sklearn.impute import SimpleImputer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, confusion_matrix, roc_auc_score
from sklearn.model_selection import GridSearchCV, StratifiedKFold
from sklearn.neighbors import KNeighborsClassifier
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler


# Settings for the cross-validation experiment.
OUTER_FOLDS = 5
INNER_FOLDS = 3
RANDOM_SEED = 6000


def read_matlab_strings(values):
    """Convert MATLAB string/cell arrays to ordinary Python strings."""
    strings = []

    for value in np.asarray(values).ravel():
        # A MATLAB cell may contain a one-element array.
        while isinstance(value, np.ndarray) and value.size == 1:
            value = value.item()

        if isinstance(value, bytes):
            value = value.decode("utf-8")

        if isinstance(value, np.ndarray):
            if value.dtype.kind in ("U", "S"):
                value = "".join(value.ravel().astype(str))
            else:
                value = str(value.tolist())

        strings.append(str(value).strip())

    return np.array(strings)


def load_site_data(data_folder, selected_site):
    """Read the provided data and separate this site's train and test records."""
    data = loadmat(data_folder / "ABIDEI_Final_Project.mat")

    # FC_edges is stored as features x subjects. Transpose to subjects x features.
    features = np.asarray(data["FC_edges"].T, dtype=float)
    labels = data["label_ASD_train_only"].ravel().astype(int)
    is_training = data["is_train"].ravel().astype(bool)
    subject_ids = read_matlab_strings(data["subject_id"])
    site_names = read_matlab_strings(data["site"])

    # Some MATLAB exports store site numbers instead of names.
    if selected_site not in site_names:
        site_codes = data["site_code"].ravel()
        known_sites = read_matlab_strings(data["site_names"])
        unique_codes = np.unique(site_codes)

        if len(unique_codes) != len(known_sites):
            raise ValueError("Cannot match site codes to site names.")

        code_to_site = dict(zip(unique_codes, known_sites))
        site_names = np.array([code_to_site[code] for code in site_codes])

    if features.shape != (386, 19900):
        raise ValueError(f"Unexpected feature shape: {features.shape}")

    if len(np.unique(subject_ids)) != len(subject_ids):
        raise ValueError("Duplicate subject IDs in the dataset.")

    site_mask = site_names == selected_site
    train_mask = site_mask & is_training
    test_mask = site_mask & ~is_training

    train_features = features[train_mask]
    train_labels = labels[train_mask]
    test_features = features[test_mask]
    test_ids = subject_ids[test_mask]

    if set(np.unique(train_labels)) != {0, 1}:
        raise ValueError("Training labels must contain both classes (0 and 1).")

    if not np.all(labels[test_mask] == -1):
        raise ValueError("Unexpected labels in the hidden-test group.")

    if min(np.bincount(train_labels)) < OUTER_FOLDS:
        raise ValueError("Not enough observations per class for cross-validation.")

    return (
        train_features,
        train_labels,
        subject_ids[train_mask],
        test_features,
        test_ids,
        site_mask,
        train_mask,
        labels,
        subject_ids,
    )


def summarize_site(data_folder, output_folder, selected_site,
                   site_mask, train_mask, labels, subject_ids, n_features):
    """Save class counts and basic demographics for the chosen site."""
    demographics = pd.read_csv(
        data_folder / "ABIDEI_three_sites_behavior.csv",
        dtype={"subject_id": str},
    )

    # Keep leading zeros so these IDs match those in the MAT file.
    id_width = max(len(subject_id) for subject_id in subject_ids)
    demographics["subject_id"] = demographics["subject_id"].str.zfill(id_width)

    study = pd.DataFrame({
        "subject_id": subject_ids[site_mask],
        "split": np.where(train_mask[site_mask], "train", "test"),
        "label": np.where(train_mask[site_mask], labels[site_mask], np.nan),
    })

    study = study.merge(
        demographics,
        on="subject_id",
        how="left",
        validate="one_to_one",
    )

    if study["age"].isna().any():
        print("Warning: some demographic records did not match the subject IDs.")

    training_labels = labels[train_mask]
    summary = {
        "site": selected_site,
        "total": int(site_mask.sum()),
        "train": int(train_mask.sum()),
        "test": int((site_mask & ~train_mask).sum()),
        "training_class_counts": (
            pd.Series(training_labels).value_counts().sort_index().to_dict()
        ),
        "age_summary": study["age"].describe().to_dict(),
        "sex_counts_as_coded": study["sex"].value_counts(dropna=False).to_dict(),
        "features": n_features,
        "cross_validation": "5 outer folds, 3 inner folds; stratified",
    }

    (output_folder / "dataset_summary.json").write_text(
        json.dumps(summary, indent=2, default=str)
    )
    study.to_csv(output_folder / "site_demographics.csv", index=False)


def calculate_metrics(true_labels, probabilities):
    """Calculate classification metrics using a 0.5 probability cutoff."""
    predicted_labels = (np.asarray(probabilities) >= 0.5).astype(int)
    tn, fp, fn, tp = confusion_matrix(
        true_labels,
        predicted_labels,
        labels=[0, 1],
    ).ravel()

    sensitivity = tp / (tp + fn) if (tp + fn) else None
    specificity = tn / (tn + fp) if (tn + fp) else None

    return {
        "accuracy": accuracy_score(true_labels, predicted_labels),
        "sensitivity": sensitivity,
        "specificity": specificity,
        "roc_auc": roc_auc_score(true_labels, probabilities),
        "tn": int(tn),
        "fp": int(fp),
        "fn": int(fn),
        "tp": int(tp),
    }


def build_models():
    """Define the three methods and the settings tested for each."""
    common_steps = [
        ("impute", SimpleImputer(strategy="median")),
        ("scale", StandardScaler()),
    ]

    logistic_model = Pipeline(common_steps + [
        ("select", SelectKBest(f_classif)),
        ("clf", LogisticRegression(max_iter=3000)),
    ])

    lda_model = Pipeline(common_steps + [
        ("pca", PCA(svd_solver="randomized", random_state=RANDOM_SEED)),
        ("clf", LinearDiscriminantAnalysis()),
    ])

    knn_model = Pipeline(common_steps + [
        ("pca", PCA(svd_solver="randomized", random_state=RANDOM_SEED)),
        ("clf", KNeighborsClassifier()),
    ])

    return {
        "Logistic regression": (
            logistic_model,
            {"select__k": [50, 200], "clf__C": [0.01, 0.1, 1.0]},
        ),
        "PCA + LDA": (
            lda_model,
            {"pca__n_components": [10, 20]},
        ),
        "PCA + KNN": (
            knn_model,
            {"pca__n_components": [10, 20], "clf__n_neighbors": [3, 7]},
        ),
    }


def compare_models(train_features, train_labels, train_ids, output_folder):
    """Tune within each training fold, then evaluate on held-out subjects."""
    models = build_models()

    outer_cv = StratifiedKFold(
        n_splits=OUTER_FOLDS,
        shuffle=True,
        random_state=RANDOM_SEED,
    )
    inner_cv = StratifiedKFold(
        n_splits=INNER_FOLDS,
        shuffle=True,
        random_state=2026,
    )

    fold_results = []
    held_out_predictions = []

    for model_name, (pipeline, parameters) in models.items():
        # Each subject will receive one prediction from an outer held-out fold.
        out_of_fold_probabilities = np.full(len(train_labels), np.nan)

        for fold_number, (fit_rows, validation_rows) in enumerate(
            outer_cv.split(train_features, train_labels),
            start=1,
        ):
            search = GridSearchCV(
                estimator=clone(pipeline),
                param_grid=parameters,
                cv=inner_cv,
                scoring="roc_auc",
                n_jobs=1,
                refit=True,
            )

            search.fit(train_features[fit_rows], train_labels[fit_rows])
            probabilities = search.predict_proba(
                train_features[validation_rows]
            )[:, 1]
            out_of_fold_probabilities[validation_rows] = probabilities

            fold_metrics = calculate_metrics(
                train_labels[validation_rows],
                probabilities,
            )

            fold_results.append({
                "model": model_name,
                "fold": fold_number,
                "inner_auc": search.best_score_,
                **fold_metrics,
                "best_params": str(search.best_params_),
            })

        if not np.isfinite(out_of_fold_probabilities).all():
            raise ValueError(f"Missing validation predictions for {model_name}")

        for row_number, subject_id in enumerate(train_ids):
            held_out_predictions.append({
                "model": model_name,
                "subject_id": subject_id,
                "true_label": int(train_labels[row_number]),
                "out_of_fold_probability": float(
                    out_of_fold_probabilities[row_number]
                ),
            })

    pd.DataFrame(fold_results).to_csv(
        output_folder / "outer_fold_metrics.csv",
        index=False,
    )

    predictions = pd.DataFrame(held_out_predictions)
    predictions.to_csv(
        output_folder / "out_of_fold_predictions.csv",
        index=False,
    )

    model_results = []

    for model_name in models:
        model_rows = predictions[predictions["model"] == model_name]
        model_metrics = calculate_metrics(
            model_rows["true_label"].to_numpy(),
            model_rows["out_of_fold_probability"].to_numpy(),
        )
        model_results.append({"model": model_name, **model_metrics})

    comparison = pd.DataFrame(model_results)
    comparison = comparison.sort_values("roc_auc", ascending=False)
    comparison.to_csv(output_folder / "model_comparison.csv", index=False)

    return comparison, models, inner_cv


def predict_test_set(comparison, models, inner_cv,
                     train_features, train_labels, test_features,
                     test_ids, selected_site, output_folder):
    """Refit the selected model on all labeled subjects, then predict test IDs."""
    best_name = comparison.iloc[0]["model"]
    pipeline, parameters = models[best_name]

    search = GridSearchCV(
        estimator=clone(pipeline),
        param_grid=parameters,
        cv=inner_cv,
        scoring="roc_auc",
        n_jobs=1,
        refit=True,
    )
    search.fit(train_features, train_labels)

    probabilities = search.predict_proba(test_features)[:, 1]
    predictions = pd.DataFrame({
        "subject_id": test_ids,
        "predicted_label": (probabilities >= 0.5).astype(int),
        "predicted_probability": probabilities,
    })

    if predictions["subject_id"].duplicated().any():
        raise ValueError("Duplicate test IDs.")

    predictions.to_csv(
        output_folder / f"{selected_site}_test_predictions.csv",
        index=False,
    )

    selected_model = {
        "site": selected_site,
        "selected_model": best_name,
        "selection_rule": "Highest pooled out-of-fold ROC AUC",
        "best_full_training_parameters": search.best_params_,
        "inner_cv_auc": search.best_score_,
        "note": "Site-only predictions; not the final combined submission.",
    }

    (output_folder / "final_model.json").write_text(
        json.dumps(selected_model, indent=2)
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--data-dir", type=Path, required=True)
    parser.add_argument("--site", choices=["NYU", "UM_1", "USM"], default="NYU")
    parser.add_argument("--out", type=Path, default=Path("results"))
    args = parser.parse_args()

    args.out.mkdir(parents=True, exist_ok=True)

    (train_features, train_labels, train_ids,
     test_features, test_ids, site_mask, train_mask,
     labels, subject_ids) = load_site_data(args.data_dir, args.site)

    summarize_site(
        args.data_dir,
        args.out,
        args.site,
        site_mask,
        train_mask,
        labels,
        subject_ids,
        train_features.shape[1],
    )

    comparison, models, inner_cv = compare_models(
        train_features,
        train_labels,
        train_ids,
        args.out,
    )

    predict_test_set(
        comparison,
        models,
        inner_cv,
        train_features,
        train_labels,
        test_features,
        test_ids,
        args.site,
        args.out,
    )

    print(comparison.to_string(index=False))
    print("Results saved to:", args.out.resolve())


if __name__ == "__main__":
    main()
