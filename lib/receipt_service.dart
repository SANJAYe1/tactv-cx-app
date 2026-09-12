import 'package:url_launcher/url_launcher.dart';

class ReceiptService {
  static Future<void> sendWhatsAppReceipt(
    String phone,
    String name,
    double amount,
  ) async {
    if (phone.isEmpty) return;

    final targetPhone = phone.startsWith('91') ? phone : "91$phone";
    final message =
        "Hello $name,\n\nWe have received your payment of Rs.$amount for your TACTV connection. Thank you!";
    final encodedMessage = Uri.encodeComponent(message);

    final whatsappUrl = Uri.parse(
      "https://wa.me/$targetPhone?text=$encodedMessage",
    );

    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    }
  }
}
