# Changelog

The following changes have been made in the dHCP Structural Pipeline v1.2 compared to v1.1:
- added support from M-CRIB atlases
- added support for reconstruction only from segmentation
- updated to latest third-party software

---

For the third data release we've made the following changes:
- Update to DrawEM 1.2.1. This has improvements to cerebellum segmentation. 
- New defacer. Previously, we used the FSL defacer, which was based on adult brains and could occasionally fail. The new defacer should be more reliable.

---

The following changes have been made in the dHCP Structural Pipeline v1.1 compared to v1.0:
- T1 is registered to T2 with an initial rigid registration, and a consequent BBR registration
- Myelin mapping (T1/T2 ratio) is calculated prior to bias field correction
- Cortical thickness is estimated the average distance between a) the Euclidean distance from the
    white surface to the closest vertex in the pial surface and b) the Euclidean distance from the pial
    surface to the closest vertex in the white surface
- Fast collision detection is disabled in white and pial surface reconstruction
