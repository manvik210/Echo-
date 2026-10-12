import SwiftUI

extension Color {
    static let navy = Color(red: 10/255, green: 22/255, blue: 40/255)
    static let gold = Color(red: 201/255, green: 162/255, blue: 75/255)
}

struct HomeView: View {
    var body: some View {
        ZStack {
            Color.navy.ignoresSafeArea()
            Text("Echo")
                .font(.largeTitle.weight(.semibold))
                .foregroundColor(.gold)
        }
    }
}
