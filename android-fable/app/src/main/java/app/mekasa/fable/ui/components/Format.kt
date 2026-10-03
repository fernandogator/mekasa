package app.mekasa.fable.ui.components

import java.util.Locale

/** `$1,234.56`-style money for the dashboard and spending screens. */
fun money(amount: Double, currency: String = "USD"): String {
    val symbol = when (currency.uppercase()) {
        "USD" -> "$"
        "EUR" -> "€"
        "GBP" -> "£"
        else -> "$currency "
    }
    return symbol + String.format(Locale.US, "%,.2f", amount)
}

fun moneyCompact(amount: Double, currency: String = "USD"): String {
    val symbol = if (currency.uppercase() == "USD") "$" else "$currency "
    return if (amount >= 1000) symbol + String.format(Locale.US, "%,.0f", amount) else money(amount, currency)
}

fun plural(count: Int, singular: String, pluralForm: String = singular + "s"): String =
    "$count ${if (count == 1) singular else pluralForm}"

fun miles(distance: Double): String = String.format(Locale.US, "%.1f mi", distance)
