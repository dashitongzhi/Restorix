import SwiftUI

struct IconChoiceButton: View {
    let icon: AppIconChoice
    let isSelected: Bool
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 9) {
                ZStack(alignment: .topTrailing) {
                    iconPreview
                        .frame(width: 68, height: 68)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                        .shadow(color: .black.opacity(0.12), radius: 4, y: 2)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.accentColor)
                            .background(Circle().fill(Color(nsColor: .windowBackgroundColor)))
                            .offset(x: 7, y: -7)
                    }
                }

                Text(title)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 116)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.07))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : Color.secondary.opacity(0.16), lineWidth: isSelected ? 2 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ViewBuilder
    private var iconPreview: some View {
        if let image = icon.image {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(1, contentMode: .fit)
        } else {
            Image(systemName: "app.dashed")
                .resizable()
                .aspectRatio(1, contentMode: .fit)
                .foregroundStyle(.secondary)
                .padding(12)
        }
    }
}
