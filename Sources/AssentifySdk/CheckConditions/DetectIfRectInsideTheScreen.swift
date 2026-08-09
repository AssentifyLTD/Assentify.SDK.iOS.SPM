import UIKit

class DetectIfRectInsideTheScreen {
    func isRectWithinMargins(
        rect: CGRect
    ) -> Bool {

         let screenBounds = UIScreen.main.bounds
            
         let horizontalPadding = screenBounds.width *  0.10
         let verticalPadding = screenBounds.height *  0.10
            
         let paddedArea = screenBounds.insetBy(dx: horizontalPadding, dy: verticalPadding)
                    
        return  paddedArea.contains(rect)
    }
}
