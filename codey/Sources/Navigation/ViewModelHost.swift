import SwiftUI

/// Builds a view model once, on first appearance. SwiftUI can re-run a
/// view's init whenever its parent updates (e.g. while a cover is being
/// dismissed), so a view model whose init has side effects (starting a study
/// session or a quiz, which save) must not be built there.
struct ViewModelHost<Model: AnyObject, Content: View>: View {
    let make: () -> Model
    @ViewBuilder let content: (Model) -> Content

    @State private var model: Model?

    var body: some View {
        if let model {
            content(model)
        } else {
            Color.clear.onAppear { model = make() }
        }
    }
}
