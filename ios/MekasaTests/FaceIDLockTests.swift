import XCTest
@testable import Mekasa

/// Optional Face ID / Touch ID gate preference and presentation rules.
final class FaceIDLockTests: XCTestCase {

    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        let suite = "FaceIDLockTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        UserDefaults.standard.removeObject(forKey: FaceIDLock.preferenceKey)
        FaceIDLock.shared.disable()
    }

    override func tearDown() {
        defaults.removeObject(forKey: FaceIDLock.preferenceKey)
        defaults = nil
        UserDefaults.standard.removeObject(forKey: FaceIDLock.preferenceKey)
        FaceIDLock.shared.disable()
        super.tearDown()
    }

    func testPreferenceKeyIsStable() {
        XCTAssertEqual(FaceIDLock.preferenceKey, "mekasa.faceIDLockEnabled")
    }

    func testBackgroundGraceIsTenSeconds() {
        XCTAssertEqual(FaceIDLock.backgroundGraceSeconds, 10)
    }

    private func makeLock(
        authenticate: @escaping (String) async -> Result<Void, Error> = { _ in .success(()) },
        biometryAvailable: Bool = true
    ) -> FaceIDLock {
        FaceIDLock(
            defaults: defaults,
            authenticate: authenticate,
            biometryAvailable: biometryAvailable,
            biometryLabel: "Face ID"
        )
    }

    func testPreferenceDefaultsOff() {
        XCTAssertFalse(makeLock().isEnabled)
    }

    func testPreferenceTogglePersists() {
        let lock = makeLock()
        lock.isEnabled = true
        XCTAssertTrue(lock.isEnabled)
        XCTAssertTrue(defaults.bool(forKey: FaceIDLock.preferenceKey))
        lock.disable()
        XCTAssertFalse(lock.isEnabled)
        XCTAssertTrue(lock.isUnlocked)
    }

    @MainActor
    func testEnableWithPromptSetsPreferenceOnSuccess() async {
        let lock = makeLock()
        let ok = await lock.enableWithPrompt()
        XCTAssertTrue(ok)
        XCTAssertTrue(lock.isEnabled)
        XCTAssertTrue(lock.isUnlocked)
    }

    @MainActor
    func testEnableWithPromptLeavesPreferenceOffOnFailure() async {
        struct Boom: LocalizedError {
            var errorDescription: String? { "denied" }
        }
        let lock = makeLock { _ in .failure(Boom()) }
        let ok = await lock.enableWithPrompt()
        XCTAssertFalse(ok)
        XCTAssertFalse(lock.isEnabled)
        XCTAssertEqual(lock.statusMessage, "denied")
    }

    @MainActor
    func testEnableWithPromptFailsWhenBiometryUnavailable() async {
        let lock = makeLock(biometryAvailable: false)
        let ok = await lock.enableWithPrompt()
        XCTAssertFalse(ok)
        XCTAssertFalse(lock.isEnabled)
        XCTAssertEqual(
            lock.statusMessage,
            "Face ID isn’t available. Check Settings → Face ID & Passcode."
        )
    }

    @MainActor
    func testUnlockSetsUnlockedOnSuccess() async {
        let lock = makeLock()
        lock.markLockedForTesting()
        await lock.unlock()
        XCTAssertTrue(lock.isUnlocked)
        XCTAssertNil(lock.statusMessage)
    }

    @MainActor
    func testPrepareForHomeLocksWhenEnabled() {
        let lock = makeLock()
        lock.isEnabled = true
        lock.prepareForHome(isUITesting: false)
        XCTAssertFalse(lock.isUnlocked)
        lock.markUnlockedForTesting()
        // Second prepare (SwiftUI onAppear) must not bounce the lock screen back.
        lock.prepareForHome(isUITesting: false)
        XCTAssertTrue(lock.isUnlocked)
        lock.prepareForHome(isUITesting: true)
        XCTAssertTrue(lock.isUnlocked)
    }

    @MainActor
    func testPrepareForHomeStaysUnlockedWhenDisabled() {
        let lock = makeLock()
        lock.isEnabled = false
        lock.prepareForHome(isUITesting: false)
        XCTAssertTrue(lock.isUnlocked)
    }

    func testPolicyHidesLockWhenDisabledOrUnlockedOrTesting() {
        XCTAssertFalse(
            FaceIDLockPolicy.shouldPresentLock(
                enabled: false,
                unlocked: false,
                onboardingDone: true,
                isUITesting: false
            )
        )
        XCTAssertFalse(
            FaceIDLockPolicy.shouldPresentLock(
                enabled: true,
                unlocked: true,
                onboardingDone: true,
                isUITesting: false
            )
        )
        XCTAssertFalse(
            FaceIDLockPolicy.shouldPresentLock(
                enabled: true,
                unlocked: false,
                onboardingDone: false,
                isUITesting: false
            )
        )
        XCTAssertFalse(
            FaceIDLockPolicy.shouldPresentLock(
                enabled: true,
                unlocked: false,
                onboardingDone: true,
                isUITesting: true
            )
        )
    }

    func testPolicyShowsLockWhenEnabledLockedAndHomeOpen() {
        XCTAssertTrue(
            FaceIDLockPolicy.shouldPresentLock(
                enabled: true,
                unlocked: false,
                onboardingDone: true,
                isUITesting: false
            )
        )
    }

    @MainActor
    func testSceneGraceKeepsUnlockedForBriefBackground() {
        let lock = makeLock()
        lock.isEnabled = true
        lock.markUnlockedForTesting()
        lock.sceneDidEnterBackground()
        lock.sceneDidBecomeActive(onboardingDone: true, isUITesting: false)
        XCTAssertTrue(lock.isUnlocked, "Brief background should stay inside the grace window")
    }

    @MainActor
    func testSceneActiveWithoutBackgroundDoesNotRelock() {
        let lock = makeLock()
        lock.isEnabled = true
        lock.markUnlockedForTesting()
        // LA / notification shade use inactive→active with no background stamp.
        lock.sceneDidBecomeActive(onboardingDone: true, isUITesting: false)
        XCTAssertTrue(lock.isUnlocked, "Must not re-lock after Face ID sheet dismisses")
    }

    @MainActor
    func testSceneActiveAfterGraceRelocks() {
        let lock = makeLock()
        lock.isEnabled = true
        lock.markUnlockedForTesting()
        lock.markBackgroundedForTesting(secondsAgo: FaceIDLock.backgroundGraceSeconds + 1)
        lock.sceneDidBecomeActive(onboardingDone: true, isUITesting: false)
        XCTAssertFalse(lock.isUnlocked)
    }

    @MainActor
    func testEnableClearsBackgroundSoLADoesNotRelock() async {
        let lock = makeLock()
        lock.markBackgroundedForTesting(secondsAgo: FaceIDLock.backgroundGraceSeconds + 5)
        let ok = await lock.enableWithPrompt()
        XCTAssertTrue(ok)
        lock.sceneDidBecomeActive(onboardingDone: true, isUITesting: false)
        XCTAssertTrue(lock.isUnlocked)
    }

    @MainActor
    func testAllowThroughAfterSignInSkipsImmediateLock() {
        let lock = makeLock()
        lock.isEnabled = true
        lock.markBackgroundedForTesting(secondsAgo: FaceIDLock.backgroundGraceSeconds + 5)
        lock.allowThroughAfterSignIn()
        XCTAssertTrue(lock.isUnlocked)
        lock.prepareForHome(isUITesting: false)
        XCTAssertTrue(lock.isUnlocked, "Fresh sign-in must not Face ID-lock over Google dismiss")
        lock.sceneDidBecomeActive(onboardingDone: true, isUITesting: false)
        XCTAssertTrue(lock.isUnlocked)
    }

    @MainActor
    func testSceneBackgroundNotArmedWhileAuthBusy() {
        let lock = makeLock()
        lock.isEnabled = true
        lock.markUnlockedForTesting()
        lock.sceneDidEnterBackground(arm: false)
        lock.markBackgroundedForTesting(secondsAgo: FaceIDLock.backgroundGraceSeconds + 5)
        // arm:false should not have set backgroundedAt; the test helper did — clear and re-check.
        lock.allowThroughAfterSignIn()
        lock.sceneDidEnterBackground(arm: false)
        lock.sceneDidBecomeActive(onboardingDone: true, isUITesting: false)
        XCTAssertTrue(lock.isUnlocked)
    }

    @MainActor
    func testResetAfterSignOutAllowsPrepareAgain() {
        let lock = makeLock()
        lock.isEnabled = true
        lock.allowThroughAfterSignIn()
        lock.resetAfterSignOut()
        lock.prepareForHome(isUITesting: false)
        XCTAssertFalse(lock.isUnlocked)
    }

    @MainActor
    func testSceneActiveSkipsLockUnderUITesting() {
        let lock = makeLock()
        lock.isEnabled = true
        lock.markLockedForTesting()
        lock.sceneDidBecomeActive(onboardingDone: true, isUITesting: true)
        XCTAssertTrue(lock.isUnlocked)
    }
}
