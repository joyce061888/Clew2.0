#import "TagFinder.h"
#import "ImageConversion.h"
#import "ImageDisplay.h"
#import "Foundation/Foundation.h"
#ifdef __cplusplus
#import <visp3/visp.h>
#import <opencv2/core.hpp>
#include <opencv2/highgui.hpp>
#include <opencv2/imgproc.hpp>
#include <opencv2/calib3d.hpp>
#endif

@interface imageToData ()
@end

@implementation imageToData
@synthesize tags;
@synthesize april;
@synthesize cam;
@synthesize detector;
@synthesize cMo;

//! [initializes imageToData object]
- (instancetype)init {
    if (self = [super init]) {
        _tags = [[NSMutableArray alloc] init];
        vpDetectorAprilTag::vpAprilTagFamily tagFamily = vpDetectorAprilTag::TAG_36h11;
        detector = new vpDetectorAprilTag (tagFamily);
        _cMo = std::vector<vpHomogeneousMatrix>();
    }
    return self;
}

//! [return number of april tags in an image]
- (int)getNumberOfTags {
    return (int)detector->getNbObjects();
}

cv::Matx41d rotvecToQuaternion(const cv::Matx31d& rotvec)
{
    double angle = norm(rotvec);
    cv::Matx31d axis(rotvec(0) / angle, rotvec(1) / angle, rotvec(2) / angle);
    double angle_2 = angle / 2;
    //qx, qy, qz, qw
    return cv::Matx41d(axis(0) * sin(angle_2), axis(1) * sin(angle_2), axis(2) * sin(angle_2), cos(angle_2));
}

cv::Matx31d quaternionToRotvec(const cv::Matx41d& q)
{
    double angle = 2*acos(q(3));
    return cv::Matx31d(angle/sin(angle/2)*q(0), angle/sin(angle/2)*q(1), angle/sin(angle/2)*q(2));
}

//! [return specificied april tag detected in an image]
// int index = <the specified april tag to return>
- (AprilTags)getTagAtIndex:(int)index {
    april.number = detector->getTagsId()[index];
    for(unsigned int i=0; i < 4; i++) {
        for(unsigned int j=0; j < 4; j++) {
            april.poseData[i*4+j] = _cMo[index][i][j];
        }
    }
    std::vector< std::vector< vpImagePoint> > imagePoints = detector->getTagsCorners();
    std::map< int, double > idSizeMap = {{-1, 0.173}};
    std::vector<std::vector<vpPoint>> tagsPoints = detector->getTagsPoints3D(detector->getTagsId(), idSizeMap);
    
    std::vector<cv::Point3f> list_points3d;
    std::vector<cv::Point2f> list_points2d;
    
    for (unsigned int i = 0; i < tagsPoints[index].size(); i++) {
        float X, Y, Z;

        X = tagsPoints[index][i].get_oX();
        Y = tagsPoints[index][i].get_oY();
        Z = tagsPoints[index][i].get_oZ();
        list_points3d.push_back(cv::Point3f(X, Y, Z));
    }
    
    int numCorners = 4;
    for (unsigned int i = 0; i < numCorners; i++) {
        double x = 0, y = 0;
        vpPixelMeterConversion::convertPoint(cam, imagePoints[index][i], x, y);
        april.imagePoints[2*i] = imagePoints[index][i].get_j();
        april.imagePoints[2*i+1] = imagePoints[index][i].get_i();
        list_points2d.push_back(cv::Point2f(x, y));
    }

     // Note: trying PnP
     cv::Mat t_matrix_;
     cv::Mat R_matrix_;
     cv::Mat distCoeffs = cv::Mat::zeros(4, 1, CV_64FC1);
     cv::Mat rvec = cv::Mat::zeros(3, 1, CV_64FC1);
     cv::Mat tvec = cv::Mat::zeros(3, 1, CV_64FC1);

     bool useExtrinsicGuess = false;
     // image coordinates are normalized, so no need to specify the camera parameter
     cv::Mat A_matrix_ = cv::Mat::eye(3, 3, CV_64FC1);
     // Pose estimation
    
    // reorder 3d points to conform with cv::SOLVEPNP_IPPE_SQUARE
    list_points3d = {list_points3d[3], list_points3d[2], list_points3d[1], list_points3d[0]};
    cv::solvePnP( list_points3d, list_points2d, A_matrix_, distCoeffs, rvec, tvec, useExtrinsicGuess, cv::SOLVEPNP_IPPE_SQUARE);

    // Transforms Rotation Vector to Matrix
    Rodrigues(rvec, R_matrix_);
    t_matrix_ = tvec;

    // I know this is lame TODO: make it better
    april.poseData[0] = R_matrix_.at<double_t>(0,0);
    april.poseData[1] = -R_matrix_.at<double_t>(0,1);
    april.poseData[2] = -R_matrix_.at<double_t>(0,2);
    april.poseData[3] = t_matrix_.at<double_t>(0,0);
    april.poseData[4] = R_matrix_.at<double_t>(1,0);
    april.poseData[5] = -R_matrix_.at<double_t>(1,1);
    april.poseData[6] = -R_matrix_.at<double_t>(1,2);
    april.poseData[7] = t_matrix_.at<double_t>(1,0);;
    april.poseData[8] = R_matrix_.at<double_t>(2,0);
    april.poseData[9] = -R_matrix_.at<double_t>(2,1);
    april.poseData[10] = -R_matrix_.at<double_t>(2,2);
    april.poseData[11] = t_matrix_.at<double_t>(2,0);

    // Compute covariance matrix of rotation and translation using approach outlined at this link: https://stackoverflow.com/questions/14559382/solvepnp-returns-wrong-result
    cv::Mat K = cv::Mat::eye(3, 3, CV_64FC1);
    K.at<double_t>(0,0) = cam.get_K().getCol(0).data[0];
    K.at<double_t>(0,2) = cam.get_K().getCol(2).data[0];
    K.at<double_t>(1,1) = cam.get_K().getCol(1).data[1];
    K.at<double_t>(1,2) = cam.get_K().getCol(2).data[1];

    double step = 1e-5;
    cv::Matx41d quat = rotvecToQuaternion(rvec);
    cv::Mat quatJacobian(list_points2d.size()*2, quat.rows, CV_64F);
    for (int i = 0; i < quat.rows; i++) {
        std::vector<cv::Point2f> pPos, pNeg;
        cv::Matx41d quatNegStep = quat;
        quatNegStep(i) -= step;
        // normalize the quaternion TODO: not sure that this is necessary to do.  It probably makes sense for the interaction with g2o's MQT type (minimal quaternion)
        quatNegStep = quatNegStep*(1/sqrt(quatNegStep.dot(quatNegStep)));
        cv::Matx31d rvecNegStep = quaternionToRotvec(quatNegStep);
        cv::projectPoints(list_points3d, rvecNegStep, t_matrix_, K, cv::Mat(), pNeg);

        cv::Matx41d quatPosStep = quat;
        quatPosStep(i) += step;
        // normalize the quaternion TODO: not sure that this is necessary to do.  It probably makes sense for the interaction with g2o's MQT type (minimal quaternion)
        quatPosStep = quatPosStep*(1/sqrt(quatPosStep.dot(quatPosStep)));
        cv::Matx31d rvecPosStep = quaternionToRotvec(quatPosStep);
        cv::projectPoints(list_points3d, rvecPosStep, t_matrix_, K, cv::Mat(), pPos);
        for (unsigned int j = 0; j < pPos.size(); j++) {
            quatJacobian.at<double_t>(j*2, i) = (pPos[j].x - pNeg[j].x)/(2*step);
            quatJacobian.at<double_t>(j*2+1, i) = (pPos[j].y - pNeg[j].y)/(2*step);
        }
    }
    cv::Mat transJacobian(list_points2d.size()*2, tvec.rows, CV_64F);
    for (int i = 0; i < tvec.rows; i++) {
        std::vector<cv::Point2f> pPos, pNeg;
        cv::Matx31d tvecNegStep = tvec;
        tvecNegStep(i) -= step;
        cv::projectPoints(list_points3d, rvec, tvecNegStep, K, cv::Mat(), pNeg);

        cv::Matx31d tvecPosStep = tvec;
        tvecPosStep(i) += step;
        cv::projectPoints(list_points3d, rvec, tvecPosStep, K, cv::Mat(), pPos);
        for (unsigned int j = 0; j < pPos.size(); j++) {
            transJacobian.at<double_t>(j*2, i) = (pPos[j].x - pNeg[j].x)/(2*step);
            transJacobian.at<double_t>(j*2+1, i) = (pPos[j].y - pNeg[j].y)/(2*step);
        }
    }
    
    // TODO: investigate whether we need to compute the full, non-diagonal covariance of translation and rotation
    cv::Mat SigmaTrans = cv::Mat(transJacobian.t() * transJacobian).inv();
    cv::Mat SigmaQuat = cv::Mat(quatJacobian.t() * quatJacobian).inv();
    
    for (int i = 0; i < 3; i++) {
        april.transVecVar[i] = SigmaTrans.diag().at<double_t>(i);
    }
    for (int i = 0; i < 4; i++) {
        april.quatVar[i] = SigmaQuat.diag().at<double_t>(i);
    }

    cv::Mat jointJacobian;
    cv::hconcat(transJacobian, quatJacobian, jointJacobian);
    cv::Mat SigmaJoint = cv::Mat(jointJacobian.t() * jointJacobian).inv();
    
    // unroll the covariance data into a matrix
    for (int i = 0; i < SigmaJoint.size[0]; i++) {
        for (int j = 0; j < SigmaJoint.size[1]; j++) {
            april.jointCovar[i*SigmaJoint.size[1] + j] = SigmaJoint.at<double_t>(i, j);
        }
    }
    
    return april;
}

//! [detect april tags]
// UIImage *img = <the image in which to search for april tags>
// float fx = <camera focal length along x axis>
// float fy = <camera focal length along y axis>
// float cx = <principal point offset along x axis>
// float cy = <principal point offset along y axis>
- (void)findTags:(UIImage *)img :(float)fx :(float)fy :(float)cx :(float)cy {
     // Convert image to visp
     vpImage<unsigned char> I = [ImageConversion vpImageGrayFromUIImage:img];
    
     // Detect AprilTag
     vpDetectorAprilTag::vpPoseEstimationMethod poseEstimationMethod = vpDetectorAprilTag::HOMOGRAPHY_VIRTUAL_VS;
     double tagSize = 0.173; // Size of 8.5x11" printed april tags
     float quad_decimate = 1.0;
     int nThreads = 1;
    
     // Set camera parameters
     cam.initPersProjWithoutDistortion(fx, fy, cx, cy); // Gets camera intrinsics from ARFrame
    
     // Initialize apriltag detector
     detector->setAprilTagQuadDecimate(quad_decimate);
     detector->setAprilTagPoseEstimationMethod(poseEstimationMethod);
     detector->setAprilTagNbThreads(nThreads);
     _cMo.clear();
     // Detect all the tags in the image
     detector->detect(I, tagSize, cam, _cMo);
    
}

@end
