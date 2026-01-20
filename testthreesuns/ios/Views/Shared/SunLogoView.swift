import SwiftUI
import UIKit

struct SunLogoView: View {
    var size: CGFloat = 40
    
    var body: some View {
        Group {
            if let logoImage = UIImage(named: "threesuns") {
                Image(uiImage: logoImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
            } else {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: size))
                    .foregroundColor(.white)
            }
        }
    }
}
