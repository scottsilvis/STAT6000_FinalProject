#!/usr/bin/env python3
"""STAT 6000 single-site ABIDE I classification. Run: python run_analysis.py --data-dir PATH --site NYU"""
import argparse, json, warnings
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


def as_strings(a):
    """Convert common MATLAB cell/string array layouts to comparable strings."""
    a=np.asarray(a).ravel()
    out=[]
    for z in a:
        while isinstance(z,np.ndarray) and z.size==1:
            z=z.item()
        if isinstance(z,bytes): z=z.decode('utf-8')
        if isinstance(z,np.ndarray):
            if z.dtype.kind in ('U','S'): z=''.join(z.ravel().astype(str))
            else: z=str(z.tolist())
        out.append(str(z).strip())
    return np.array(out)


def metrics(y,p):
    yp=(np.asarray(p)>=0.5).astype(int)
    tn,fp,fn,tp=confusion_matrix(y,yp,labels=[0,1]).ravel()
    return dict(accuracy=accuracy_score(y,yp),sensitivity=tp/(tp+fn) if tp+fn else None,
                specificity=tn/(tn+fp) if tn+fp else None,roc_auc=roc_auc_score(y,p),
                tn=int(tn),fp=int(fp),fn=int(fn),tp=int(tp))


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--data-dir',type=Path,required=True)
    ap.add_argument('--site',choices=['NYU','UM_1','USM'],default='NYU')
    ap.add_argument('--out',type=Path,default=Path('results'))
    args=ap.parse_args();args.out.mkdir(parents=True,exist_ok=True)
    data=loadmat(args.data_dir/'ABIDEI_Final_Project.mat')
    X=np.asarray(data['FC_edges'].T,dtype=float)
    y=np.asarray(data['label_ASD_train_only']).ravel().astype(int)
    train=np.asarray(data['is_train']).ravel().astype(bool)
    site=as_strings(data['site'])
    if not np.isin(args.site,site):
        codes=np.asarray(data['site_code']).ravel()
        names=as_strings(data['site_names'])
        valid=np.unique(codes)
        if len(names)!=len(valid): raise ValueError('Cannot map site identifiers reliably')
        mapping=dict(zip(valid,names));site=np.array([mapping[x] for x in codes])
    ids=as_strings(data['subject_id'])
    if X.shape!=(386,19900): raise ValueError(f'Unexpected feature matrix shape {X.shape}')
    if len(set(ids))!=len(ids):raise ValueError('Duplicate subject IDs')
    if not np.isfinite(X).all():warnings.warn('Non-finite FC values detected; imputing in-fold')
    chosen=site==args.site
    tr=chosen&train;te=chosen&~train
    Xtr,ytr=X[tr],y[tr]; Xte=X[te]; ids_te=ids[te]
    assert set(np.unique(ytr))=={0,1} and np.all(y[te]==-1)
    if min(np.bincount(ytr))<5:raise ValueError('Insufficient observations for 5-fold stratification')
    demographics=pd.read_csv(args.data_dir/'ABIDEI_three_sites_behavior.csv',dtype={'subject_id':str})
    demographics['subject_id']=demographics['subject_id'].str.zfill(max(map(len,ids)))
    study=pd.DataFrame({'subject_id':ids[chosen],'split':np.where(train[chosen],'train','test'),
                        'label':np.where(train[chosen],y[chosen],np.nan)})
    study=study.merge(demographics,on='subject_id',how='left',validate='one_to_one')
    if study['age'].isna().any():warnings.warn('Demographic subjects not all matched; check IDs')
    summary={'site':args.site,'total':int(chosen.sum()),'train':int(tr.sum()),'test':int(te.sum()),
             'training_class_counts':pd.Series(ytr).value_counts().sort_index().to_dict(),
             'age_summary':study['age'].describe().to_dict(),
             'sex_counts_as_coded':study['sex'].value_counts(dropna=False).to_dict(),
             'features':X.shape[1], 'cross_validation':'5-fold stratified nested CV, shuffle random_state=6000'}
    (args.out/'dataset_summary.json').write_text(json.dumps(summary,indent=2,default=str))
    study.to_csv(args.out/'site_demographics.csv',index=False)
    cv_outer=StratifiedKFold(n_splits=5,shuffle=True,random_state=6000)
    cv_inner=StratifiedKFold(n_splits=3,shuffle=True,random_state=2026)
    common=[('impute',SimpleImputer(strategy='median')),('scale',StandardScaler())]
    models={
      'Logistic regression':(Pipeline(common+[('select',SelectKBest(f_classif)),
                            ('clf',LogisticRegression(max_iter=3000))]),
                            {'select__k':[50,200],'clf__C':[0.01,0.1,1.0]}),
      'PCA + LDA':(Pipeline(common+[('pca',PCA(svd_solver='randomized',random_state=6000)),
                           ('clf',LinearDiscriminantAnalysis())]),{'pca__n_components':[10,20]}),
      'PCA + KNN':(Pipeline(common+[('pca',PCA(svd_solver='randomized',random_state=6000)),
                           ('clf',KNeighborsClassifier())]),
                           {'pca__n_components':[10,20],'clf__n_neighbors':[3,7]})
    }
    rows=[];oof=[]
    for name,(pipe,grid) in models.items():
        scores=np.full(len(ytr),np.nan)
        for fold,(a,b) in enumerate(cv_outer.split(Xtr,ytr),1):
            tuner=GridSearchCV(clone(pipe),grid,cv=cv_inner,scoring='roc_auc',n_jobs=1,refit=True)
            tuner.fit(Xtr[a],ytr[a])
            probs=tuner.predict_proba(Xtr[b])[:,1]
            scores[b]=probs
            rows.append({'model':name,'fold':fold,'inner_auc':tuner.best_score_,
                         **metrics(ytr[b],probs),'best_params':str(tuner.best_params_)})
        assert np.isfinite(scores).all()
        oof.extend({'model':name,'subject_id':ids[tr][i],'true_label':int(ytr[i]),
                    'out_of_fold_probability':float(scores[i])} for i in range(len(ytr)))
    pd.DataFrame(rows).to_csv(args.out/'outer_fold_metrics.csv',index=False)
    oof=pd.DataFrame(oof);oof.to_csv(args.out/'out_of_fold_predictions.csv',index=False)
    agg=[]
    for name in models:
        q=oof[oof.model==name]
        agg.append({'model':name,**metrics(q.true_label.to_numpy(),q.out_of_fold_probability.to_numpy())})
    table=pd.DataFrame(agg).sort_values('roc_auc',ascending=False)
    table.to_csv(args.out/'model_comparison.csv',index=False)
    winner=table.iloc[0]['model'];pipe,grid=models[winner]
    tuner=GridSearchCV(clone(pipe),grid,cv=cv_inner,scoring='roc_auc',n_jobs=1,refit=True)
    tuner.fit(Xtr,ytr)
    pred=tuner.predict_proba(Xte)[:,1]
    submission=pd.DataFrame({'subject_id':ids_te,'predicted_label':(pred>=0.5).astype(int),
                             'predicted_probability':pred})
    assert len(submission)==te.sum() and submission.subject_id.is_unique
    assert set(submission.predicted_label.unique()).issubset({0,1})
    submission.to_csv(args.out/f'{args.site}_test_predictions.csv',index=False)
    (args.out/'final_model.json').write_text(json.dumps({'site':args.site,'selected_model':winner,
     'selection_rule':'highest pooled out-of-fold ROC AUC from nested CV',
     'best_full_training_parameters':tuner.best_params_, 'inner_cv_auc':tuner.best_score_,
     'important':'Only selected-site test records are included; confirm submission format with instructor.'},indent=2))
    print(table.to_string(index=False));print('Wrote results to',args.out.resolve())

if __name__=='__main__':main()
