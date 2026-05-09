import SwiftUI

func deleteConfirmationBinding<T>(for item: Binding<T?>) -> Binding<Bool> {
    DeleteConfirmationBinding(item: item).binding()
}

private struct DeleteConfirmationBinding<T>: @unchecked Sendable {
    let item: Binding<T?>

    func binding() -> Binding<Bool> {
        Binding {
        item.wrappedValue != nil
        } set: { isPresented in
            if !isPresented {
                item.wrappedValue = nil
            }
        }
    }
}

struct DraftBinding<Draft, Value>: @unchecked Sendable {
    let draft: Binding<Draft?>
    let getValue: @Sendable (Draft?) -> Value
    let setValue: @Sendable (inout Draft, Value) -> Void
    let ensureDraft: @Sendable () -> Void
    let commitDraft: @Sendable () -> Void

    func binding() -> Binding<Value> {
        Binding {
            getValue(draft.wrappedValue)
        } set: { newValue in
            ensureDraft()
            guard var currentDraft = draft.wrappedValue else { return }
            setValue(&currentDraft, newValue)
            draft.wrappedValue = currentDraft
            commitDraft()
        }
    }
}

struct DeferredDraftBinding<Draft, Value>: @unchecked Sendable {
    let draft: Binding<Draft?>
    let getValue: @Sendable (Draft?) -> Value
    let setValue: @Sendable (inout Draft, Value) -> Void
    let ensureDraft: @Sendable () -> Void

    func binding() -> Binding<Value> {
        Binding {
            getValue(draft.wrappedValue)
        } set: { newValue in
            ensureDraft()
            guard var currentDraft = draft.wrappedValue else { return }
            setValue(&currentDraft, newValue)
            draft.wrappedValue = currentDraft
        }
    }
}
