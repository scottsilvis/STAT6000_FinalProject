ABIDE I THREE-SITE FINAL PROJECT — STUDENT DATA

Files:
- ABIDEI_Final_Project.mat: combined FC data, training labels and split indicator
- ABIDEI_three_sites_behavior.csv: demographics, no diagnosis labels

386 subjects: NYU 179, UM_1 107, USM 100. 269 training, 117 test.
Each FC matrix is 200 x 200; FC_edges has shape 19900 x 386 (features x subjects).
FC matrices are symmetric Fisher-z-transformed Pearson correlations from NONFILTERED time series, with zero diagonal.

MAT variables:
FC_matrices: 200 x 200 x 386
FC_edges: 19900 x 386
subject_id: 386 x 1 pseudonymous IDs
site, site_code, site_names: site identifiers
roi_i, roi_j: 1-based indices of each of 19,900 unique ROI pairs
n_roi: 200
label_ASD_train_only: 386 x 1, 0=control, 1=ASD, -1=hidden test
is_train: 386 x 1, 1=training, 0=test

Use only labeled training data for model development and cross-validation.
Do not fit scaling, feature selection, PCA, or tuning on the test subjects.
Submit predictions with the original test subject_id in the same order.

Python example:
  import scipy.io as sio
  D = sio.loadmat('ABIDEI_Final_Project.mat')
  X = D['FC_edges'].T  # 386 x 19900
  y = D['label_ASD_train_only'].ravel()
  train = D['is_train'].ravel().astype(bool)
  X_train, y_train, X_test = X[train], y[train], X[~train]


R example (R.matlab package):
 # Run once: install.packages("R.matlab")
library(R.matlab)
D <- readMat("ABIDEI_Final_Project.mat")
X <- t(D$FC.edges)  # 386 subjects x 19,900 features
y <- as.vector(D$label.ASD.train.only)
train <- as.logical(as.vector(D$is.train))
X_train <- X[train, , drop = FALSE]
y_train <- y[train]
X_test <- X[!train, , drop = FALSE]
test_ids <- as.vector(D$subject.id)[!train]
dim(X_train)  # 269 x 19900
dim(X_test)   # 117 x 19900
table(y_train)
# Fit preprocessing and models using training subjects only.
# Use test_ids in the same order when submitting predictions.


MATLAB example:
  D = load('ABIDEI_Final_Project.mat');
  X = D.FC_edges';
  train = logical(D.is_train);
  Xtrain = X(train,:); ytrain = D.label_ASD_train_only(train);
  Xtest = X(~train,:);

Important: Hidden test labels are NOT included in this archive.
The original supplied ZIP also did not contain the instructor-only full labels or the referenced class_project_splits.mat.
