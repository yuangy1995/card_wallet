import SwiftUI

public struct CardBrandIcon: View {
    public let brand: CardBrand
    
    public init(brand: CardBrand) {
        self.brand = brand
    }
    
    public var body: some View {
        switch brand {
        case .visa:
            // 维萨卡标：标志性的斜角和科技深蓝/霓虹黄字样
            Text("VISA")
                .font(.system(.title3, design: .serif))
                .bold()
                .italic()
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: true)
                .foregroundStyle(LinearGradient(colors: [Color.blue, Color.cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: .blue.opacity(0.3), radius: 4)
                
        case .mastercard:
            // 万事达卡标：经典的红黄双圆半透明交叠
            HStack(spacing: -8) {
                Circle()
                    .fill(Color.red.opacity(0.85))
                    .frame(width: 22, height: 22)
                Circle()
                    .fill(Color.orange.opacity(0.85))
                    .frame(width: 22, height: 22)
            }
            .shadow(color: .red.opacity(0.2), radius: 4)
            
        case .amex:
            // 运通卡标：科技冷蓝正方形，内嵌斜体 AMEX 镂空字样
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(LinearGradient(colors: [Color(white: 0.15), Color.blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 32, height: 22)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Color.cyan.opacity(0.8), lineWidth: 1)
                    )
                Text("AMEX")
                    .font(.system(size: 8, weight: .black, design: .default))
                    .foregroundColor(.white)
            }
            .shadow(color: .cyan.opacity(0.4), radius: 4)
            
        case .dinersClub:
            // 大莱卡标（双环星轨概念设计）：象征“环球旅行”，绘制一外一内两个精密的同心圆形切角环
            ZStack {
                Circle()
                    .stroke(LinearGradient(colors: [Color.blue, Color.purple], startPoint: .top, endPoint: .bottom), lineWidth: 2)
                    .frame(width: 20, height: 20)
                Circle()
                    .stroke(Color.cyan, lineWidth: 1.5)
                    .frame(width: 14, height: 14)
                // 地球经纬斜线条
                Path { path in
                    path.move(to: CGPoint(x: 3, y: 10))
                    path.addLine(to: CGPoint(x: 17, y: 10))
                    path.move(to: CGPoint(x: 10, y: 3))
                    path.addLine(to: CGPoint(x: 10, y: 17))
                }
                .stroke(Color.cyan.opacity(0.6), lineWidth: 1)
                .frame(width: 20, height: 20)
            }
            .shadow(color: .blue.opacity(0.4), radius: 5)
            
        case .discover:
            // 发现卡标（极极简流光）：极简的 "DISCOVER" 字样，末尾带霓虹橙光圈
            HStack(spacing: 3) {
                Text("DISCOVER")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .tracking(0.5)
                    .foregroundColor(.white)
                Circle()
                    .fill(RadialGradient(colors: [Color.orange, Color.red], center: .center, startRadius: 0, endRadius: 8))
                    .frame(width: 10, height: 10)
                    .shadow(color: .orange, radius: 4)
            }
            
        case .jcb:
            // JCB卡标：蓝、红、绿三圆角纵柱内嵌 J、C、B 镂空字样
            HStack(spacing: 1.5) {
                ZStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(LinearGradient(colors: [Color.blue, Color(red: 0.1, green: 0.3, blue: 0.8)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 9, height: 16)
                    Text("J")
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }
                ZStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(LinearGradient(colors: [Color.red, Color(red: 0.8, green: 0.1, blue: 0.2)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 9, height: 16)
                    Text("C")
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }
                ZStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(LinearGradient(colors: [Color(red: 0.1, green: 0.6, blue: 0.2), Color(red: 0.2, green: 0.8, blue: 0.3)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 9, height: 16)
                    Text("B")
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            .shadow(color: .blue.opacity(0.25), radius: 3)
            
        case .unionpay:
            // 银联卡标：三色平行斜向渐变色带，重叠交错并镂空内嵌微型 UnionPay 字样
            HStack(spacing: -3.5) {
                // 1. 红色倾斜色带
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(LinearGradient(colors: [.red, Color(red: 0.8, green: 0.0, blue: 0.15)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 12, height: 16)
                    .skew(x: -0.16)
                
                // 2. 深蓝色倾斜色带
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(LinearGradient(colors: [Color(red: 0.0, green: 0.15, blue: 0.45), Color(red: 0.05, green: 0.25, blue: 0.65)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 12, height: 16)
                    .skew(x: -0.16)
                
                // 3. 青绿色倾斜色带
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(LinearGradient(colors: [Color(red: 0.0, green: 0.45, blue: 0.4), Color(red: 0.0, green: 0.65, blue: 0.55)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 12, height: 16)
                    .skew(x: -0.16)
            }
            .overlay(
                Text("UnionPay")
                    .font(.system(size: 5, weight: .black, design: .default))
                    .foregroundColor(.white)
                    .italic()
                    .offset(y: -0.5)
                    .shadow(color: .black.opacity(0.4), radius: 1, x: 0.5, y: 0.5)
            )
            .shadow(color: .blue.opacity(0.3), radius: 4)
            
        case .unknown:
            ZStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(white: 0.15))
                    .frame(width: 24, height: 18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                    )
                Image(systemName: "creditcard.and.123")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
        }
    }
}

extension View {
    func skew(x: CGFloat = 0, y: CGFloat = 0) -> some View {
        self.projectionEffect(ProjectionTransform(CGAffineTransform(a: 1, b: y, c: x, d: 1, tx: 0, ty: 0)))
    }
}
