import SwiftUI

struct ManageCategoriesView: View {
    @EnvironmentObject var vm: StreamsViewModel
    @State private var newCategoryName = ""
    @State private var editingCategory: StreamCategory? = nil
    @State private var editingName      = ""
    @FocusState private var addFieldFocused: Bool

    var body: some View {
        List {
            // Add new category inline
            Section {
                HStack {
                    TextField("New category name", text: $newCategoryName)
                        .focused($addFieldFocused)
                        .onSubmit { commitAdd() }
                    Button(action: commitAdd) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.spPink)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .disabled(newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } footer: {
                Text("Drag to reorder. Swipe to delete — streams will move to Uncategorized.")
            }

            // Existing categories
            Section {
                ForEach(vm.categories) { category in
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(Color.spBlue)
                            .frame(width: 24)

                        if editingCategory?.id == category.id {
                            // Inline rename
                            TextField("Category name", text: $editingName)
                                .focused($addFieldFocused)
                                .onSubmit { commitRename() }
                            Spacer()
                            Button("Done") { commitRename() }
                                .font(.subheadline.bold())
                                .foregroundStyle(Color.spPink)
                        } else {
                            Text(category.name)
                            Spacer()
                            Text("\(streamCount(for: category))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button {
                                editingCategory = category
                                editingName     = category.name
                                addFieldFocused = true
                            } label: {
                                Image(systemName: "pencil")
                                    .foregroundStyle(Color.spBlue)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .onMove  { vm.moveCategories(from: $0, to: $1) }
                .onDelete { vm.removeCategories(at: $0) }
            } header: {
                Text("Categories (\(vm.categories.count))")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Manage Categories")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.editMode, .constant(.active))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
                    .tint(Color.spPink)
            }
        }
    }

    // MARK: - Helpers

    private func commitAdd() {
        let trimmed = newCategoryName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        vm.addCategory(name: trimmed)
        newCategoryName = ""
        addFieldFocused = false
    }

    private func commitRename() {
        let trimmed = editingName.trimmingCharacters(in: .whitespaces)
        if let cat = editingCategory, !trimmed.isEmpty {
            vm.renameCategory(id: cat.id, to: trimmed)
        }
        editingCategory = nil
        addFieldFocused = false
    }

    private func streamCount(for category: StreamCategory) -> Int {
        category.streamIDs.count
    }
}
