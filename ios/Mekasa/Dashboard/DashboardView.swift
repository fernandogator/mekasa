import PhotosUI
import SwiftUI
import UIKit

/// Home dashboard: hero home photo, low stock, pending approvals, recent activity.
/// Satisfies: UI-004 AC1–AC3 (150px home photo hero per design system)
/// Spec version: 1.0
struct DashboardView: View {
    @EnvironmentObject private var session: AppSession
    @Binding var selectedTab: MainTab
    @State private var toast: String?
    @State private var selectedItemID: String?
    @State private var showInventory = false
    @State private var showHomePhoto = false

    init(selectedTab: Binding<MainTab> = .constant(.home)) {
        _selectedTab = selectedTab
    }

    private var pendingApprovals: [ShoppingListItem] {
        session.shoppingList.filter { $0.needsApproval && !$0.isChecked }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                homeHero
                    .zIndex(1)

                VStack(alignment: .leading, spacing: 32) {
                    statsRow
                        .padding(.top, 8)
                    lowStockSection
                    needsApprovalSection
                    recentActivitySection
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 140)
                .offset(y: -28)
            }
        }
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(TestIdentifiers.dashboardView)
        .navigationDestination(item: $selectedItemID) { itemID in
            ItemDetailView(itemID: itemID)
        }
        .navigationDestination(isPresented: $showInventory) {
            InventoryListView()
        }
        .fullScreenCover(isPresented: $showHomePhoto) {
            HomePhotoView()
                .environmentObject(session)
        }
        .overlay(alignment: .top) {
            if let toast {
                Text(toast)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(MekasaTheme.brand)
                    .clipShape(Capsule())
                    .padding(.top, 56)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: toast)
        .animation(.easeInOut(duration: 0.2), value: pendingApprovals.map(\.id))
    }

    /// 150px full-bleed hero with home photo (DESIGN_SYSTEM / UI-004 AC3).
    private var homeHero: some View {
        ZStack(alignment: .topTrailing) {
            Button {
                showHomePhoto = true
            } label: {
                ZStack {
                    HouseholdPhotoView(urlString: session.household?.photoURL)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()

                    LinearGradient(
                        colors: [
                            MekasaTheme.brand.opacity(0.10),
                            MekasaTheme.brand.opacity(0.35),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    VStack(spacing: 8) {
                        Text(greeting)
                            .font(MekasaTheme.labelFont)
                            .tracking(1.2)
                            .textCase(.uppercase)
                            .foregroundStyle(MekasaTheme.brandMuted)
                        Text(householdTitle)
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .shadow(color: .black.opacity(0.25), radius: 4, y: 1)

                        if session.household?.photoURL == nil {
                            Text("Tap to add a home photo")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.9))
                                .padding(.top, 2)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 28)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 178)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(TestIdentifiers.homePhotoHero)
            .accessibilityLabel(
                session.household?.photoURL == nil
                    ? "Add home photo"
                    : "Home photo for \(householdTitle). Double tap to change."
            )

            Button {
                showToast(session.isRealtimeSyncActive
                           ? "Live sync is on — inventory updates across devices"
                           : "Turn on notifications in Settings to get invite alerts")
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(0.22))
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                    if !pendingApprovals.isEmpty {
                        Circle()
                            .fill(MekasaTheme.accent)
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(Color.white, lineWidth: 1))
                            .offset(x: -2, y: 2)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.top, 54)
            .padding(.trailing, 20)
            .accessibilityLabel("Notifications")
        }
        .clipShape(
            UnevenRoundedRectangle(
                bottomLeadingRadius: 40,
                bottomTrailingRadius: 40,
                style: .continuous
            )
        )
    }

    private var lowStockItems: [InventoryItem] {
        session.inventory.filter(\.isLowStock)
    }

    private var lowStockSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Low stock")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(MekasaTheme.brand)
                Spacer()
                Button("All inventory") {
                    showInventory = true
                }
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(MekasaTheme.textMuted)
                .accessibilityIdentifier(TestIdentifiers.allInventoryButton)
                .accessibilityLabel("All inventory")
            }
            if lowStockItems.isEmpty {
                Text("Nothing below threshold right now.")
                    .font(MekasaTheme.bodyFont)
                    .foregroundStyle(MekasaTheme.textMuted)
            } else {
                ForEach(lowStockItems) { item in
                    Button {
                        selectedItemID = item.id
                    } label: {
                        HStack(spacing: 14) {
                            ProductThumbnail(urlString: item.imageURL, size: 56, cornerRadius: 16)
                                .accessibilityIdentifier(TestIdentifiers.itemThumbnail)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(MekasaTheme.brand)
                                Text("Qty \(item.quantity) · threshold \(item.lowStockThreshold)")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(MekasaTheme.textMuted)
                            }
                            Spacer()
                            // REQ-021 AC2: flag items a family member should avoid.
                            AffectedMembersChip(warnings: session.memberWarnings(for: item.health))
                            Image(systemName: "chevron.right")
                                .foregroundStyle(MekasaTheme.textMuted)
                        }
                        .padding(14)
                        .background(MekasaTheme.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens item details")
                }
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 16) {
            Button {
                showInventory = true
            } label: {
                statCard(
                    icon: "exclamationmark.circle",
                    iconBg: Color(red: 0xfc / 255, green: 0xe5 / 255, blue: 0xe7 / 255),
                    label: "Low Stock",
                    value: "\(session.lowStockCount) items"
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(TestIdentifiers.lowStockStatButton)
            .accessibilityLabel("Low stock")

            Button {
                selectedTab = .spend
            } label: {
                statCard(
                    icon: "creditcard",
                    iconBg: Color(red: 0xea / 255, green: 0xf1 / 255, blue: 0xec / 255),
                    label: "Spend",
                    value: String(format: "$%.0f", displayedSpend),
                    suffix: "/cap"
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var displayedSpend: Double {
        session.spendingReport?.total ?? session.localTrackedSpend
    }

    private func statCard(
        icon: String,
        iconBg: Color,
        label: String,
        value: String,
        suffix: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(MekasaTheme.brand)
                    .frame(width: 32, height: 32)
                    .background(iconBg)
                    .clipShape(Circle())
                Text(label)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(MekasaTheme.textMuted)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(MekasaTheme.brand)
                if let suffix {
                    Text(suffix)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(MekasaTheme.textMuted)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MekasaTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(MekasaTheme.brandMuted.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    private var needsApprovalSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Needs Approval")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(MekasaTheme.brand)
                Spacer()
                Button("View All") {
                    selectedTab = .list
                }
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(MekasaTheme.textMuted)
            }

            if pendingApprovals.isEmpty {
                Text("You're all caught up.")
                    .font(MekasaTheme.bodyFont)
                    .foregroundStyle(MekasaTheme.textMuted)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MekasaTheme.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .accessibilityIdentifier(TestIdentifiers.emptyStateView)
            } else {
                VStack(spacing: 4) {
                    ForEach(pendingApprovals) { item in
                        approvalRow(item)
                    }
                }
                .padding(8)
                .background(MekasaTheme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(MekasaTheme.brandMuted.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.08), radius: 24, y: 12)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(TestIdentifiers.requestQueue)
            }
        }
    }

    private func approvalRow(_ item: ShoppingListItem) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "cart")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(MekasaTheme.brand)
                .frame(width: 40, height: 40)
                .background(Color(red: 0xf1 / 255, green: 0xf4 / 255, blue: 0xf3 / 255))
                .clipShape(Circle())
                .accessibilityIdentifier(TestIdentifiers.itemThumbnail)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(MekasaTheme.brand)
                    .accessibilityIdentifier(TestIdentifiers.requestedItemLabel)
                Text("Requested by \(item.requestedBy ?? "member")")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(MekasaTheme.textMuted)
                    .accessibilityIdentifier(TestIdentifiers.requestorLabel)
            }

            Spacer()

            if session.isHouseholdOwner {
                Button {
                    dismiss(item, approved: false)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(MekasaTheme.brand)
                        .frame(width: 40, height: 40)
                        .overlay(Circle().stroke(MekasaTheme.brandMuted.opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Deny \(item.name)")
                .accessibilityIdentifier(TestIdentifiers.rejectButton)

                Button {
                    dismiss(item, approved: true)
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(MekasaTheme.brand)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Approve \(item.name)")
                .accessibilityIdentifier(TestIdentifiers.approveButton)
            }
        }
        .padding(12)
        .accessibilityIdentifier(TestIdentifiers.requestCell)
    }

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Activity")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(MekasaTheme.brand)

            VStack(alignment: .leading, spacing: 16) {
                ForEach(session.activity) { item in
                    HStack(alignment: .top, spacing: 16) {
                        Circle()
                            .fill(item.kind == .warning
                                  ? Color(red: 0xc4 / 255, green: 0x5c / 255, blue: 0x12 / 255)
                                  : MekasaTheme.success)
                            .frame(width: 8, height: 8)
                            .padding(.top, 8)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(MekasaTheme.brand)
                            Text(item.when)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .tracking(0.8)
                                .textCase(.uppercase)
                                .foregroundStyle(MekasaTheme.textMuted)
                        }
                    }
                }
            }
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5 ..< 12: return "Good Morning"
        case 12 ..< 17: return "Good Afternoon"
        default: return "Good Evening"
        }
    }

    private var householdTitle: String {
        if let name = session.household?.name, !name.isEmpty {
            return name
        }
        return "Your house"
    }

    private func dismiss(_ item: ShoppingListItem, approved: Bool) {
        if approved {
            session.approveShoppingRequest(id: item.id)
            showToast("Approved \(item.name)")
        } else {
            session.rejectShoppingRequest(id: item.id)
            showToast("Denied \(item.name)")
        }
    }

    private func showToast(_ message: String) {
        toast = message
        Task {
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            if toast == message { toast = nil }
        }
    }
}

#Preview {
    MekasaScreen {
        DashboardView()
            .environmentObject({
                let s = AppSession()
                s.household = PreviewFixtures.household(name: "The Rodriguez House")
                return s
            }())
    }
}

// MARK: - Home photo picker

/// Add or replace the household home photo from camera or photo library,
/// name the house, and pinch/drag to crop the image for the dashboard hero.
/// Satisfies: REQ-002 AC1–AC3, UI-004 AC3
/// Spec version: 1.0
struct HomePhotoView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss

    @State private var houseName: String = ""
    @State private var sourceImage: UIImage?
    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var localError: String?
    @State private var cropScale: CGFloat = 1
    @State private var cropOffset: CGSize = .zero
    @State private var cropFrameSize: CGSize = CGSize(width: 320, height: 220)
    @State private var userReplacedImage = false

    private var initialName: String {
        session.household?.name ?? ""
    }

    private var nameChanged: Bool {
        houseName.trimmingCharacters(in: .whitespacesAndNewlines)
            != initialName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var cropChanged: Bool {
        abs(cropScale - 1) > 0.01
            || abs(cropOffset.width) > 0.5
            || abs(cropOffset.height) > 0.5
    }

    private var imageDirty: Bool {
        userReplacedImage || (sourceImage != nil && cropChanged)
    }

    private var saveEnabled: Bool {
        !session.isBusy && (nameChanged || imageDirty)
    }

    var body: some View {
        MekasaScreen {
            VStack(spacing: 0) {
                HStack {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(MekasaTheme.textMuted)
                        .accessibilityIdentifier(TestIdentifiers.cancelButton)
                    Spacer()
                    Text("Home photo")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(MekasaTheme.brand)
                    Spacer()
                    Button("Save") {
                        Task { await save() }
                    }
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(saveEnabled ? MekasaTheme.accent : MekasaTheme.textMuted)
                    .disabled(!saveEnabled)
                    .accessibilityIdentifier(TestIdentifiers.saveButton)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 8)

                ScrollView {
                    VStack(spacing: 24) {
                        Text("Name your house and frame the photo for the home screen.")
                            .font(MekasaTheme.bodyFont)
                            .foregroundStyle(MekasaTheme.textMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.top, 12)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("House name")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(MekasaTheme.textMuted)
                            TextField("e.g. The Guerrero Home", text: $houseName)
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundStyle(MekasaTheme.brand)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(MekasaTheme.surfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(MekasaTheme.brandMuted.opacity(0.35), lineWidth: 1)
                                )
                                .textInputAutocapitalization(.words)
                                .disableAutocorrection(true)
                                .accessibilityIdentifier(TestIdentifiers.homePhotoNameField)
                        }
                        .padding(.horizontal, 24)

                        VStack(spacing: 10) {
                            cropPreview
                                .padding(.horizontal, 24)

                            if sourceImage != nil {
                                Text("Pinch to zoom · drag to reposition")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(MekasaTheme.textMuted)
                            }
                        }

                        VStack(spacing: 12) {
                            if CameraImagePicker.isCameraAvailable {
                PrimaryButton(title: "Take photo", disabled: session.isBusy) {
                                    localError = nil
                                    showCamera = true
                                }
                                .accessibilityIdentifier(TestIdentifiers.homePhotoCameraButton)
                            }

                            PhotosPicker(selection: $photoItem, matching: .images) {
                                Text("Choose from Photos")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .foregroundStyle(MekasaTheme.brand)
                                    .background(MekasaTheme.surfaceElevated)
                                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                                            .stroke(MekasaTheme.brandMuted.opacity(0.35), lineWidth: 1)
                                    )
                            }
                            .disabled(session.isBusy)
                            .accessibilityIdentifier(TestIdentifiers.homePhotoLibraryButton)
                        }
                        .padding(.horizontal, 24)

                        if let localError {
                            Text(localError)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(MekasaTheme.accent)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        } else if let message = session.lastError {
                            Text(message)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(MekasaTheme.accent)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }

                        Text("Owners can update this anytime. Members see it on the dashboard hero.")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(MekasaTheme.textMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.bottom, 40)
                }

                StickyBottomBar(progress: nil) {
                    PrimaryButton(
                        title: "Save",
                        disabled: !saveEnabled,
                        isLoading: session.isBusy
                    ) {
                        Task { await save() }
                    }
                    .accessibilityIdentifier(TestIdentifiers.homePhotoSaveBottomButton)
                }
            }
        }
        .accessibilityIdentifier(TestIdentifiers.homePhotoView)
        .onAppear { seedFromHousehold() }
        .onChange(of: photoItem) { _, item in
            Task { await loadLibraryItem(item) }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraImagePicker(image: Binding(
                get: { sourceImage },
                set: { newImage in
                    sourceImage = newImage
                    if newImage != nil {
                        userReplacedImage = true
                        resetCrop()
                    }
                }
            ))
            .ignoresSafeArea()
        }
    }

    private var cropPreview: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                MekasaTheme.brand.opacity(0.08)
                if let sourceImage {
                    HomePhotoCropCanvas(
                        image: sourceImage,
                        scale: $cropScale,
                        offset: $cropOffset,
                        frameSize: size
                    )
                } else {
                    HouseholdPhotoView(urlString: session.household?.photoURL)
                }
            }
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(MekasaTheme.brandMuted.opacity(0.35), lineWidth: 1)
            )
            .onAppear { cropFrameSize = size }
            .onChange(of: size) { _, newSize in
                cropFrameSize = newSize
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .accessibilityIdentifier(TestIdentifiers.homePhotoPreview)
    }

    private func seedFromHousehold() {
        houseName = session.household?.name ?? ""
        if sourceImage == nil,
           let existing = HouseholdPhotoImage.uiImage(from: session.household?.photoURL) {
            sourceImage = existing
        }
    }

    private func resetCrop() {
        cropScale = 1
        cropOffset = .zero
    }

    private func loadLibraryItem(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data)
            else {
                localError = "Couldn’t read that photo. Try another one."
                return
            }
            sourceImage = image
            userReplacedImage = true
            resetCrop()
            localError = nil
        } catch {
            localError = error.localizedDescription
        }
    }

    private func save() async {
        guard saveEnabled else { return }
        localError = nil
        session.lastError = nil

        var cropped: UIImage?
        if imageDirty, let sourceImage {
            cropped = HomePhotoCropCanvas.render(
                image: sourceImage,
                scale: cropScale,
                offset: cropOffset,
                frameSize: cropFrameSize
            ) ?? sourceImage
        }

        let ok = await session.saveHomePhotoEdits(
            name: houseName,
            image: cropped,
            nameChanged: nameChanged,
            imageChanged: cropped != nil
        )
        if ok {
            dismiss()
        } else if session.lastError == nil {
            localError = "Couldn’t save home details."
        }
    }
}

/// Pinch-to-zoom and drag-to-pan canvas; exports the visible crop for the hero.
struct HomePhotoCropCanvas: View {
    let image: UIImage
    @Binding var scale: CGFloat
    @Binding var offset: CGSize
    let frameSize: CGSize

    @State private var gestureScale: CGFloat = 1
    @State private var gestureOffset: CGSize = .zero

    private var fillScale: CGFloat {
        guard image.size.width > 0, image.size.height > 0, frameSize.width > 0, frameSize.height > 0 else {
            return 1
        }
        return max(frameSize.width / image.size.width, frameSize.height / image.size.height)
    }

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .frame(
                width: image.size.width * fillScale * scale * gestureScale,
                height: image.size.height * fillScale * scale * gestureScale
            )
            .offset(
                x: offset.width + gestureOffset.width,
                y: offset.height + gestureOffset.height
            )
            .frame(width: frameSize.width, height: frameSize.height)
            .contentShape(Rectangle())
            .gesture(
                SimultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            gestureScale = value
                        }
                        .onEnded { value in
                            let next = max(1, min(scale * value, 4))
                            scale = next
                            gestureScale = 1
                            clampOffset()
                        },
                    DragGesture()
                        .onChanged { value in
                            gestureOffset = value.translation
                        }
                        .onEnded { value in
                            offset.width += value.translation.width
                            offset.height += value.translation.height
                            gestureOffset = .zero
                            clampOffset()
                        }
                )
            )
    }

    private func clampOffset() {
        let drawnW = image.size.width * fillScale * scale
        let drawnH = image.size.height * fillScale * scale
        let maxX = max(0, (drawnW - frameSize.width) / 2)
        let maxY = max(0, (drawnH - frameSize.height) / 2)
        offset.width = min(maxX, max(-maxX, offset.width))
        offset.height = min(maxY, max(-maxY, offset.height))
    }

    /// Renders the visible crop into a bitmap matching the preview frame.
    static func render(
        image: UIImage,
        scale: CGFloat,
        offset: CGSize,
        frameSize: CGSize
    ) -> UIImage? {
        guard frameSize.width > 1, frameSize.height > 1,
              image.size.width > 0, image.size.height > 0
        else { return nil }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = UIScreen.main.scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: frameSize, format: format)
        return renderer.image { _ in
            let fill = max(frameSize.width / image.size.width, frameSize.height / image.size.height)
            let total = fill * max(scale, 1)
            let drawn = CGSize(
                width: image.size.width * total,
                height: image.size.height * total
            )
            let origin = CGPoint(
                x: (frameSize.width - drawn.width) / 2 + offset.width,
                y: (frameSize.height - drawn.height) / 2 + offset.height
            )
            image.draw(in: CGRect(origin: origin, size: drawn))
        }
    }
}

#Preview {
    NavigationStack {
        HomePhotoView()
            .environmentObject({
                let s = AppSession()
                s.isUIPreview = true
                s.household = PreviewFixtures.household(name: "The Demo House")
                return s
            }())
    }
}
