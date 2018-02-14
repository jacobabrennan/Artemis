

//-- Preprocessor --------------------------------------------------------------

#define CERES_VERSION "0.9"
#define CERES_PREFERENCES_VERSION 3

#define CERES_PATH_PREFERENCES "[ARTEMIS_PATH_DATA]/preferences"
#define CERES_PATH_STATS "[ARTEMIS_PATH_DATA]/stats"
#define CERES_MAX_NICKNAME_LENGTH 20

#define CERES_LOAD_KEY(theKey) theKey = objectData[#theKey]
#define CERES_SAVE_KEY(theKey) objectData[#theKey] = theKey