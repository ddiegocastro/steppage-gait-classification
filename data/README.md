# Data

Raw data are **not redistributed**. Download the *Pathological Gait Datasets* (Kinect v2) from
<https://github.com/kooksung/pathological_gait_datasets> and arrange:

```
data/
├── Normal/    human<N>_normal<M>/human<N>_normal<M>_SkeletonData<1-6>.csv
└── Steppage/  human<N>_steppage<M>/human<N>_steppage<M>_SkeletonData<1-6>.csv
```

Each CSV row: `time, [joint_id, x, y, z] × 25 joints`. `SkeletonData1–6` are six simultaneous Kinect views of the same trial.
Update the two paths in `PathGaitFeatureExtraction` (`rutas`) to point here.
