package app.mekasa.fable.ui.shopping

import app.mekasa.fable.data.model.Household
import app.mekasa.fable.data.model.SavedStore
import app.mekasa.fable.data.model.ShoppingItem
import app.mekasa.fable.data.model.Store

/**
 * Pure rules for one shopping list per store and for the store picker, kept out of
 * the composables so they can be unit tested.
 *
 * A list is keyed by the store's ID, or [ANY] for "Any store"; [ALL] is the selector
 * entry that shows every row. Satisfies: REQ-024 AC5, AC7; REQ-003 AC11
 */
object ShoppingStores {
    const val ALL = "all"
    const val ANY = "any"
    const val ALL_LABEL = "All stores"
    const val ANY_LABEL = "Any store"

    /** One entry in the store selector. Satisfies: REQ-024 AC7 */
    data class Tab(val key: String, val label: String, val toBuy: Int)

    /**
     * The list a row is on: its store when that store is still saved, otherwise "Any store"
     * (REQ-024 AC1, AC5). Satisfies: REQ-024 AC7
     */
    fun listKey(storeId: String?, saved: List<SavedStore>): String =
        if (storeId != null && saved.any { it.id == storeId }) storeId else ANY

    /** Rows shown for [selection]; [ALL] shows every row. Satisfies: REQ-024 AC7 */
    fun filter(rows: List<ShoppingItem>, selection: String, saved: List<SavedStore>): List<ShoppingItem> =
        if (selection == ALL) rows else rows.filter { listKey(it.storeId, saved) == selection }

    /** Rows on [selection] still to buy (not checked). Satisfies: REQ-024 AC7 */
    fun toBuyCount(rows: List<ShoppingItem>, selection: String, saved: List<SavedStore>): Int =
        filter(rows, selection, saved).count { !it.isChecked }

    /** "All stores", each saved store, then "Any store", with their counts. Satisfies: REQ-024 AC7 */
    fun tabs(rows: List<ShoppingItem>, saved: List<SavedStore>): List<Tab> =
        buildList {
            add(Tab(ALL, ALL_LABEL, toBuyCount(rows, ALL, saved)))
            saved.forEach { add(Tab(it.id, it.name, toBuyCount(rows, it.id, saved))) }
            add(Tab(ANY, ANY_LABEL, toBuyCount(rows, ANY, saved)))
        }

    /** Name of the list a row is on, shown on rows while "All stores" is selected. Satisfies: REQ-024 AC7 */
    fun storeName(storeId: String?, saved: List<SavedStore>): String =
        saved.firstOrNull { it.id == listKey(storeId, saved) }?.name ?: ANY_LABEL

    /** Falls back to [ALL] when the selected store is no longer saved. Satisfies: REQ-024 AC7 */
    fun normalizedSelection(selection: String, saved: List<SavedStore>): String =
        if (selection == ALL || selection == ANY || saved.any { it.id == selection }) selection else ALL

    /** The store an add from [selection] goes to: null ("Any store") from All or Any. Satisfies: REQ-024 AC7 */
    fun storeIdForAdd(selection: String, saved: List<SavedStore>): String? =
        normalizedSelection(selection, saved).takeIf { it != ALL && it != ANY }

    /**
     * Stores checked when the picker opens: only those saved with details, so bare IDs
     * from older clients are not counted (REQ-003 AC11).
     */
    fun pickerSelection(household: Household?): Set<String> =
        household?.stores?.map { it.id }?.toSet().orEmpty()

    /**
     * Rows for the picker: the search results, then any saved store the search did not
     * return so it can still be unchecked. Satisfies: REQ-003 AC11
     */
    fun pickerCandidates(nearby: List<Store>, saved: List<SavedStore>): List<Store> {
        val ids = nearby.map { it.id }.toSet()
        return nearby + saved.filter { it.id !in ids }.map { it.toStore() }
    }

    /** Case-insensitive match on name or address. Satisfies: REQ-003 AC11 */
    fun search(stores: List<Store>, query: String): List<Store> {
        val needle = query.trim()
        if (needle.isEmpty()) return stores
        return stores.filter { it.name.contains(needle, ignoreCase = true) || it.address.contains(needle, ignoreCase = true) }
    }

    /**
     * Details to save for the checked stores, in candidate order; the IDs sent are the
     * same list's IDs (REQ-003 AC6). Satisfies: REQ-003 AC11
     */
    fun savedDetails(selected: Set<String>, candidates: List<Store>): List<SavedStore> =
        candidates.filter { it.id in selected }.distinctBy { it.id }.map { it.toSaved() }

    /** What `PUT …/stores` sends: IDs with details first, in the same order as [stores]. Satisfies: REQ-003 AC11 */
    data class StoreSelection(val storeIds: List<String>, val stores: List<SavedStore>)

    /**
     * IDs and details for the checked stores. An ID with no known details is still sent
     * (after the detailed ones) so nothing the user checked is lost. Satisfies: REQ-003 AC11
     */
    fun selectionToSave(selected: Set<String>, candidates: List<Store>): StoreSelection {
        val details = savedDetails(selected, candidates)
        val known = details.map { it.id }
        return StoreSelection(known + (selected - known.toSet()).sorted(), details)
    }

    /** Satisfies: REQ-003 AC11 */
    fun Store.toSaved(): SavedStore =
        SavedStore(id = id, name = name, address = address, distanceMiles = distanceMiles.takeIf { it > 0 })

    /** Satisfies: REQ-003 AC11 */
    fun SavedStore.toStore(): Store =
        Store(id = id, name = name, address = address, distanceMiles = distanceMiles ?: 0.0)
}
