
import Foundation
import SVGKit
import UIKit


class Guide{
    
   private var transmittingBackground :SVGKImage?
   private var cardBackground :SVGKImage?
   var cardSvgImageView :SVGKFastImageView?
   var qrSvgImageView :SVGKFastImageView?
    
   private var faceBackground :SVGKImage?
   var faceSvgImageView :SVGKFastImageView?
   private var topFaceShadow = UIView()
   private var bottomFaceShadow = UIView()
    
    func showCardGuide(view:UIView,forResource :String =  "card_background"){
           guard let modelPath = Bundle.module.path(forResource: forResource, ofType: "svg") else {
                  print("SVG file not found.")
                  return
            }

            guard let svgImage = SVGKImage(contentsOfFile: modelPath) else {
                print("Failed to load SVG image.")
                return
            }
        
        
            cardBackground = svgImage;
            cardSvgImageView = SVGKFastImageView(svgkImage: svgImage)
            cardSvgImageView!.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(cardSvgImageView!)
             NSLayoutConstraint.activate([
                cardSvgImageView!.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                cardSvgImageView!.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                cardSvgImageView!.widthAnchor.constraint(equalTo: view.widthAnchor),
                cardSvgImageView!.heightAnchor.constraint(equalTo: view.heightAnchor)
               ])
        
        guard let modelPathTransmitting = Bundle.module.path(forResource: "transmitting_background", ofType: "svg") else {
            print("SVG file not found.")
            return
        }

        guard let svgImageTransmitting = SVGKImage(contentsOfFile: modelPathTransmitting) else {
          print("Failed to load SVG image.")
          return
         }
        transmittingBackground = svgImageTransmitting;
    }
    
    
    func changeCardColor(view:UIView,to color: String,notTransmitting: Bool) {
        if cardSvgImageView == nil {
            showCardGuide(view: view)
        }
        cardSvgImageView!.removeFromSuperview()
        if(notTransmitting){
            let layerIDsToChange = ["corner_1", "corner_2", "corner_3", "corner_4","scanArea"
                                    ,"outer_corner_1", "outer_corner_2", "outer_corner_3", "outer_corner_4",
                                    "passport_top_box", "passport_info_box", "passport_photo_frame",
                                    "passport_face_head", "passport_face_body",
                                    "passport_mrz_box", "passport_mrz_row_1", "passport_mrz_row_2"]
            self.changeLayerColor(svgImage: self.cardBackground!, layerIDs: layerIDsToChange ,newColor: UIColor(hexString: color) )
            cardSvgImageView = SVGKFastImageView(svgkImage: self.cardBackground)
        }else{
            cardSvgImageView = SVGKFastImageView(svgkImage: transmittingBackground)
        }
        cardSvgImageView!.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cardSvgImageView!)
        NSLayoutConstraint.activate([
            cardSvgImageView!.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cardSvgImageView!.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cardSvgImageView!.widthAnchor.constraint(equalTo: view.widthAnchor),
            cardSvgImageView!.heightAnchor.constraint(equalTo: view.heightAnchor)
          ])
    }
    
    //// Face
    
    func showFaceGuide(view:UIView){
        guard let modelPath = Bundle.module.path(forResource: "face_background", ofType: "svg") else {
              print("SVG file not found.")
              return
          }

          guard let svgImage = SVGKImage(contentsOfFile: modelPath) else {
              print("Failed to load SVG image.")
              return
          }

          faceBackground = svgImage
          faceSvgImageView = SVGKFastImageView(svgkImage: svgImage)
          faceSvgImageView!.translatesAutoresizingMaskIntoConstraints = false

          let topShadow = UIView()
          let bottomShadow = UIView()
          [topShadow, bottomShadow].forEach {
              $0.translatesAutoresizingMaskIntoConstraints = false
              $0.backgroundColor = .black
              $0.alpha = 0.5 // Adjust shadow intensity
              view.addSubview($0)
          }

          view.addSubview(faceSvgImageView!)
          topFaceShadow = topShadow;
          bottomFaceShadow = bottomShadow;
        
          NSLayoutConstraint.activate([
              topShadow.topAnchor.constraint(equalTo: view.topAnchor),
              topShadow.leadingAnchor.constraint(equalTo: view.leadingAnchor),
              topShadow.trailingAnchor.constraint(equalTo: view.trailingAnchor),
              topShadow.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.08),

              bottomShadow.bottomAnchor.constraint(equalTo: view.bottomAnchor),
              bottomShadow.leadingAnchor.constraint(equalTo: view.leadingAnchor),
              bottomShadow.trailingAnchor.constraint(equalTo: view.trailingAnchor),
              bottomShadow.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.08),

              faceSvgImageView!.topAnchor.constraint(equalTo: topShadow.bottomAnchor),
              faceSvgImageView!.bottomAnchor.constraint(equalTo: bottomShadow.topAnchor),
              faceSvgImageView!.leadingAnchor.constraint(equalTo: view.leadingAnchor),
              faceSvgImageView!.trailingAnchor.constraint(equalTo: view.trailingAnchor)
          ])
        guard let modelPathTransmitting = Bundle.module.path(forResource: "transmitting_background", ofType: "svg") else {
            print("SVG file not found.")
            return
        }

        guard let svgImageTransmitting = SVGKImage(contentsOfFile: modelPathTransmitting) else {
          print("Failed to load SVG image.")
          return
         }
        transmittingBackground = svgImageTransmitting;
    }

    func changeFaceColor(view: UIView, to color: String, notTransmitting: Bool) {
        if faceSvgImageView == nil {
            showFaceGuide(view: view)
            return
        }

        faceSvgImageView!.removeFromSuperview()
        topFaceShadow.removeFromSuperview()
        bottomFaceShadow.removeFromSuperview()
        if notTransmitting {
            let layerIDsToChange = ["Layer_1-1"]
            self.changeLayerColor(svgImage: self.faceBackground!, layerIDs: layerIDsToChange, newColor: UIColor(hexString: color))
            faceSvgImageView = SVGKFastImageView(svgkImage: self.faceBackground)
        } else {
            faceSvgImageView = SVGKFastImageView(svgkImage: self.transmittingBackground)
        }

        faceSvgImageView!.translatesAutoresizingMaskIntoConstraints = false

        let topShadow = UIView()
        let bottomShadow = UIView()
        topFaceShadow = topShadow;
        bottomFaceShadow = bottomShadow;
        [topShadow, bottomShadow].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.backgroundColor = .black
            $0.alpha = 0.5
            view.addSubview($0)
        }

        view.addSubview(faceSvgImageView!)

        NSLayoutConstraint.activate([
            topShadow.topAnchor.constraint(equalTo: view.topAnchor),
            topShadow.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topShadow.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topShadow.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.08),

            bottomShadow.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomShadow.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomShadow.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomShadow.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier:0.08),

            faceSvgImageView!.topAnchor.constraint(equalTo: topShadow.bottomAnchor),
            faceSvgImageView!.bottomAnchor.constraint(equalTo: bottomShadow.topAnchor),
            faceSvgImageView!.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            faceSvgImageView!.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    //// Qr
    
    func showQrGuide(view:UIView){
           guard let modelPath = Bundle.module.path(forResource: "qr_background", ofType: "svg") else {
                  print("SVG file not found.")
                  return
            }

            guard let svgImage = SVGKImage(contentsOfFile: modelPath) else {
                print("Failed to load SVG image.")
                return
            }
        
        
            cardBackground = svgImage;
            qrSvgImageView = SVGKFastImageView(svgkImage: svgImage)
            qrSvgImageView!.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(qrSvgImageView!)
             NSLayoutConstraint.activate([
                qrSvgImageView!.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                qrSvgImageView!.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                qrSvgImageView!.widthAnchor.constraint(equalTo: view.widthAnchor),
                qrSvgImageView!.heightAnchor.constraint(equalTo: view.heightAnchor)
               ])
        
        guard let modelPathTransmitting = Bundle.module.path(forResource: "transmitting_background", ofType: "svg") else {
            print("SVG file not found.")
            return
        }

        guard let svgImageTransmitting = SVGKImage(contentsOfFile: modelPathTransmitting) else {
          print("Failed to load SVG image.")
          return
         }
        transmittingBackground = svgImageTransmitting;
    }
    
    
    func changeQrColor(view:UIView,to color: String,notTransmitting: Bool) {
        if qrSvgImageView == nil {
            showCardGuide(view: view)
        }
        qrSvgImageView!.removeFromSuperview()
        if(notTransmitting){
            let layerIDsToChange = ["corner_1", "corner_2", "corner_3", "corner_4","scanArea"]
            self.changeLayerColor(svgImage: self.cardBackground!, layerIDs: layerIDsToChange ,newColor: UIColor(hexString: color) )
            qrSvgImageView = SVGKFastImageView(svgkImage: self.cardBackground)
        }else{
            qrSvgImageView = SVGKFastImageView(svgkImage: transmittingBackground)
        }
        qrSvgImageView!.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(qrSvgImageView!)
        NSLayoutConstraint.activate([
            qrSvgImageView!.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            qrSvgImageView!.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            qrSvgImageView!.widthAnchor.constraint(equalTo: view.widthAnchor),
            qrSvgImageView!.heightAnchor.constraint(equalTo: view.heightAnchor)
          ])
    }
    
    
    func showSuccessLiveCheck(view: UIView) -> UIView {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = .clear
        containerView.layer.cornerRadius = 20
        containerView.layer.masksToBounds = true
        guard let modelPath = Bundle.module.path(forResource: "success_layout", ofType: "svg") else {
            print("SVG file not found.")
            return containerView
        }
        
        guard let svgImage = SVGKImage(contentsOfFile: modelPath) else {
            print("Failed to load SVG image.")
            return containerView
        }
        
     
        
        let svgImageView = SVGKFastImageView(svgkImage: svgImage)
        svgImageView!.translatesAutoresizingMaskIntoConstraints = false
        svgImageView!.contentMode = .scaleAspectFit
        
        containerView.addSubview(svgImageView!)
        view.addSubview(containerView)
        
        NSLayoutConstraint.activate([
            svgImageView!.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            svgImageView!.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            svgImageView!.topAnchor.constraint(equalTo: containerView.topAnchor),
            svgImageView!.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            svgImageView!.widthAnchor.constraint(equalToConstant: 550),
            svgImageView!.heightAnchor.constraint(equalToConstant: 550),
            
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(equalTo: svgImageView!.widthAnchor),
            containerView.heightAnchor.constraint(equalTo: svgImageView!.heightAnchor)
        ])
        
        containerView.isUserInteractionEnabled = true
        
        return containerView
    }
    
    
    func showErrorLiveCheck(view: UIView) -> UIView {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = .clear
        containerView.layer.cornerRadius = 20
        containerView.layer.masksToBounds = true
        
        guard let modelPath = Bundle.module.path(forResource: "error_layout", ofType: "svg") else {
            print("SVG file not found.")
            return containerView
        }
        
        guard let svgImage = SVGKImage(contentsOfFile: modelPath) else {
            print("Failed to load SVG image.")
            return containerView
        }
        
        let svgImageView = SVGKFastImageView(svgkImage: svgImage)
        svgImageView!.translatesAutoresizingMaskIntoConstraints = false
        svgImageView!.contentMode = .scaleAspectFit
        
        containerView.addSubview(svgImageView!)
        view.addSubview(containerView)
        
        NSLayoutConstraint.activate([
            svgImageView!.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            svgImageView!.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            svgImageView!.topAnchor.constraint(equalTo: containerView.topAnchor),
            svgImageView!.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            svgImageView!.widthAnchor.constraint(equalToConstant: 550),
            svgImageView!.heightAnchor.constraint(equalToConstant: 550),
            
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(equalTo: svgImageView!.widthAnchor),
            containerView.heightAnchor.constraint(equalTo: svgImageView!.heightAnchor)
        ])
        
        containerView.isUserInteractionEnabled = true
        
        return containerView
    }
    
    
    func setActiveLiveMove(view: UIView,event:FaceEvents) -> UIView {
        let containerView = UIView()
            containerView.translatesAutoresizingMaskIntoConstraints = false
            containerView.backgroundColor = UIColor.clear // Set to clear or any desired background color
            containerView.layer.cornerRadius = 20
            containerView.layer.masksToBounds = true

            let imageView = UIImageView()
        
        var gifImage: UIImage?

        if event == .PITCH_UP {
            gifImage = UIImage.gifImageWithName("up")
        } else if event == .PITCH_DOWN {
            gifImage = UIImage.gifImageWithName("down")
        } else if event == .YAW_RIGHT {
            gifImage = UIImage.gifImageWithName("right")
        } else if event == .YAW_LEFT {
            gifImage = UIImage.gifImageWithName("left")
        } else if event == .WINK_LEFT {
            gifImage = UIImage.gifImageWithName("wink_left")
        } else if event == .WINK_RIGHT {
            gifImage = UIImage.gifImageWithName("wink_right")
        } else if event == .BLINK {
            gifImage = UIImage.gifImageWithName("blink")
        }else if event == .GOOD {
            // do nothing
        }
        
         imageView.image = gifImage
          
            imageView.contentMode = .scaleAspectFit
            imageView.translatesAutoresizingMaskIntoConstraints = false

            containerView.addSubview(imageView)
            view.addSubview(containerView)

            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                imageView.topAnchor.constraint(equalTo: containerView.topAnchor),
                imageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
             
             
            ])
        
        if event == .WINK_RIGHT || event == .WINK_LEFT || event == .BLINK{
            NSLayoutConstraint.activate([
                imageView.widthAnchor.constraint(equalToConstant: 450),
                imageView.heightAnchor.constraint(equalToConstant: 450)
            ])
        }else{
            NSLayoutConstraint.activate([
                imageView.widthAnchor.constraint(equalToConstant: 800),
                imageView.heightAnchor.constraint(equalToConstant: 800)
            ])
        }

            NSLayoutConstraint.activate([
                containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                containerView.widthAnchor.constraint(equalTo: imageView.widthAnchor),
                containerView.heightAnchor.constraint(equalTo: imageView.heightAnchor)
            ])
            
            containerView.isUserInteractionEnabled = true

            return containerView
    }
    
 
    /// Color
    func changeLayerColor(svgImage: SVGKImage, layerIDs: [String], newColor: UIColor) {

        let filledLayers: Set<String> = [
            "scanArea",
            "Layer_1-1",
            "passport_top_box",
            "passport_info_box",
            "passport_mrz_box",
            "passport_mrz_row_1",
            "passport_mrz_row_2"
        ]

        for layerID in layerIDs {

            guard let shapeLayer = svgImage.layer(withIdentifier: layerID) as? CAShapeLayer else {
                continue
            }

            if filledLayers.contains(layerID) {

                if(layerID != "Layer_1-1"){
                    shapeLayer.fillColor = newColor.withAlphaComponent(0.30).cgColor
                }else{
                    shapeLayer.fillColor = newColor.cgColor

                }

                if layerID == "scanArea" || layerID == "passport_mrz_row_1" || layerID == "passport_mrz_row_2" {
                    shapeLayer.strokeColor = UIColor.clear.cgColor
                } else {
                    shapeLayer.strokeColor = newColor.cgColor
                }

            } else {
                shapeLayer.strokeColor = newColor.cgColor
                shapeLayer.fillColor = UIColor.clear.cgColor
            }
        }
    }
    
    
    
  
    
    func showFaceTimer(view: UIView, initialTextColorHex: String,countdownFinished: @escaping () -> Void) -> (countdownView: UIView, countdownTimer: Timer)  {
        
        let countdownLabel = UILabel()
        countdownLabel.font = UIFont.boldSystemFont(ofSize: 130)
        countdownLabel.textAlignment = .center
        countdownLabel.textColor = UIColor(hexString: initialTextColorHex)
        countdownLabel.backgroundColor = UIColor.clear
        countdownLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(countdownLabel)
        
        NSLayoutConstraint.activate([
            countdownLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            countdownLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            countdownLabel.widthAnchor.constraint(equalToConstant: 100),
            countdownLabel.heightAnchor.constraint(equalToConstant: 100)
        ])
        
        var countdownValue = 3
        countdownLabel.text = "\(countdownValue)"
        
        let countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { timer in
            if countdownValue > 1 {
                countdownValue -= 1
                countdownLabel.text = "\(countdownValue)"
            } else {
                timer.invalidate()
                countdownLabel.text = "1"
                countdownFinished()
                countdownLabel.removeFromSuperview()
            }
        }
        
        return (countdownLabel, countdownTimer)

    }
    
}

extension UIColor {
    convenience init(hexString: String) {
        var hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)

        if hex.hasPrefix("#") {
            hex.removeFirst()
        }

        var color: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&color)

        let a, r, g, b: CGFloat

        if hex.count == 8 {
            a = CGFloat((color & 0xFF000000) >> 24) / 255
            r = CGFloat((color & 0x00FF0000) >> 16) / 255
            g = CGFloat((color & 0x0000FF00) >> 8) / 255
            b = CGFloat(color & 0x000000FF) / 255
        } else { // fallback for RRGGBB
            a = 1
            r = CGFloat((color & 0xFF0000) >> 16) / 255
            g = CGFloat((color & 0x00FF00) >> 8) / 255
            b = CGFloat(color & 0x0000FF) / 255
        }

        self.init(red: r, green: g, blue: b, alpha: a)
    }
}



