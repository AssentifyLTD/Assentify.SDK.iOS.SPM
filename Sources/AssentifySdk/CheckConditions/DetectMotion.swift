

import Foundation

//let MotionLimit = 30;
//let MotionLimitFace = 5;


func calculatePercentageChange(rect1: CGRect, rect2: CGRect) -> MotionType {
    let centerX1: CGFloat = rect1.midX
    let centerY1: CGFloat = rect1.midY
    let centerX2: CGFloat = rect2.midX
    let centerY2: CGFloat = rect2.midY

    let percentageChangeX = (centerX2 - centerX1) / centerX1 * 100
    let percentageChangeY = (centerY2 - centerY1) / centerY1 * 100
    if percentageChangeX >= -4 && percentageChangeX <= 4 && percentageChangeY >= -4 && percentageChangeY <= 4 {
        return MotionType.SENDING
    }
    return MotionType.HOLD_YOUR_HAND
}


func calculateFaceMotion(rect1: CGRect, rect2: CGRect) -> MotionType {
    let centerX1: CGFloat = rect1.midX
    let centerY1: CGFloat = rect1.midY
    let centerX2: CGFloat = rect2.midX
    let centerY2: CGFloat = rect2.midY

    let percentageChangeX = (centerX2 - centerX1) / centerX1 * 100
    let percentageChangeY = (centerY2 - centerY1) / centerY1 * 100
    if percentageChangeX >= -6 && percentageChangeX <= 6 && percentageChangeY >= -6 && percentageChangeY <= 6{
        return MotionType.SENDING
    }
    return MotionType.HOLD_YOUR_HAND
}
