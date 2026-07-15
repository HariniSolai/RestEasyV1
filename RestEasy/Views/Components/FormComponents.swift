import SwiftUI

/// Styled text field matching the cream input style from mockups.
struct CreamTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    @Binding var isPasswordVisible: Bool

    init(
        placeholder: String,
        text: Binding<String>,
        isSecure: Bool = false,
        isPasswordVisible: Binding<Bool> = .constant(false)
    ) {
        self.placeholder = placeholder
        _text = text
        self.isSecure = isSecure
        _isPasswordVisible = isPasswordVisible
    }

    var body: some View {
        HStack {
            Group {
                if isSecure && !isPasswordVisible {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .foregroundStyle(AppTheme.inputText)
            .textInputAutocapitalization(isSecure ? .never : .words)
            .autocorrectionDisabled(isSecure)

            if isSecure {
                Button {
                    isPasswordVisible.toggle()
                } label: {
                    Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                        .foregroundStyle(AppTheme.inputPlaceholder)
                }
            }
        }
        .padding()
        .background(AppTheme.cream)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .colorScheme(.light)
    }
}

/// Primary action button with sage/leaf green styling.
struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline.bold())
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppTheme.primaryButton)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

/// Social sign-in button for Google or Apple.
struct SocialSignInButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3)
                Text(title)
                    .font(.body.weight(.medium))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding()
            .background(AppTheme.cream)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .colorScheme(.light)
        }
    }
}

/// Horizontal divider with centered "or" text.
struct OrDivider: View {
    var body: some View {
        HStack {
            Rectangle()
                .fill(AppTheme.cream.opacity(0.5))
                .frame(height: 1)
            Text("or")
                .foregroundStyle(AppTheme.cream)
                .font(.subheadline)
            Rectangle()
                .fill(AppTheme.cream.opacity(0.5))
                .frame(height: 1)
        }
    }
}
