

import UIKit

struct ObjectOverlay {
  let name: String
  let borderRect: CGRect
  let nameStringSize: CGSize
  let color: UIColor
  let font: UIFont
}

class OverlayView: UIView {

  var objectOverlays: [ObjectOverlay] = []
  private let stringBgAlpha: CGFloat
    = 0.7
  private let lineWidth: CGFloat = 4
  private var stringFontColor = UIColor.white
  private let stringHorizontalSpacing: CGFloat = 13.0
  private let stringVerticalSpacing: CGFloat = 7.0
  private let cornerRadius: CGFloat = 10.0
  override func draw(_ rect: CGRect) {

    for objectOverlay in objectOverlays {
     
      drawBorders(of: objectOverlay)
      drawBackground(of: objectOverlay)
      drawName(of: objectOverlay)
    }
  }

  func drawBorders(of objectOverlay: ObjectOverlay) {

      var test = objectOverlay.borderRect;
      test.origin.x =   test.origin.x - 25
      test.size.width =   test.size.width  + 50
      let path = UIBezierPath(roundedRect: test , cornerRadius: self.cornerRadius)

    path.lineWidth = lineWidth
    objectOverlay.color.setStroke()

    path.stroke()
      
  }

    func drawBackground(of objectOverlay: ObjectOverlay) {

        let stringBgRect = CGRect(
            x: objectOverlay.borderRect.origin.x - 25,
            y: objectOverlay.borderRect.origin.y,
            width: 2 * stringHorizontalSpacing + objectOverlay.nameStringSize.width,
            height: 2 * stringVerticalSpacing + objectOverlay.nameStringSize.height
        )

        let cornerRadius: CGFloat = 5.0

        let stringBgPath = UIBezierPath(roundedRect: stringBgRect, cornerRadius: cornerRadius)
        
        objectOverlay.color.withAlphaComponent(stringBgAlpha).setFill()
        stringBgPath.stroke()
    }



  func drawName(of objectOverlay: ObjectOverlay) {

     stringFontColor = objectOverlay.color;
    let stringRect = CGRect(x: objectOverlay.borderRect.origin.x + stringHorizontalSpacing - 25,
                            y: objectOverlay.borderRect.origin.y + stringVerticalSpacing, width: objectOverlay.nameStringSize.width, height: objectOverlay.nameStringSize.height)

    let attributedString = NSAttributedString(string: objectOverlay.name, attributes: [NSAttributedString.Key.foregroundColor : stringFontColor, NSAttributedString.Key.font : objectOverlay.font])
    attributedString.draw(in: stringRect)
  }

}
