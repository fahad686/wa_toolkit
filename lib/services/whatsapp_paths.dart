import '../models/status_item.dart';

enum WhatsAppVariant { regular, business }

extension WhatsAppVariantX on WhatsAppVariant {
  WhatsAppSource get source => this == WhatsAppVariant.business
      ? WhatsAppSource.business
      : WhatsAppSource.regular;

  int get sourceIndex => source.index;

  String get label => this == WhatsAppVariant.business ? 'WhatsApp Business' : 'WhatsApp';

  String get shortLabel => this == WhatsAppVariant.business ? 'Business' : 'WhatsApp';
}

/// Known SAF initial URIs and human-readable paths.
class WhatsAppPaths {
  static const regularStatuses =
      'content://com.android.externalstorage.documents/tree/primary%3AAndroid%2Fmedia%2Fcom.whatsapp%2FWhatsApp%2FMedia%2F.Statuses';

  static const businessStatuses =
      'content://com.android.externalstorage.documents/tree/primary%3AAndroid%2Fmedia%2Fcom.whatsapp.w4b%2FWhatsApp%20Business%2FMedia%2F.Statuses';

  static const humanReadableRegular =
      'Internal storage → Android → media → com.whatsapp → WhatsApp → Media → .Statuses';

  static const humanReadableBusiness =
      'Internal storage → Android → media → com.whatsapp.w4b → WhatsApp Business → Media → .Statuses';

  static String statusesUriFor(WhatsAppVariant variant) =>
      variant == WhatsAppVariant.business ? businessStatuses : regularStatuses;

  static String humanPathFor(WhatsAppVariant variant) =>
      variant == WhatsAppVariant.business ? humanReadableBusiness : humanReadableRegular;

  static String settingsKeyFor(WhatsAppVariant variant) =>
      'status_folder_uri_${variant.name}';
}

class WhatsAppGuide {
  final WhatsAppVariant variant;
  const WhatsAppGuide(this.variant);

  String get title => '${variant.label} — Setup guide';

  List<String> get steps => variant == WhatsAppVariant.business ? _businessSteps : _regularSteps;

  static const _regularSteps = [
    'Install and open regular WhatsApp (green icon).',
    'View statuses in WhatsApp — tap through each one you want to save.',
    'Come back to this app → WhatsApp tab → tap "Grant folder access".',
    'In the file picker, enable "Show hidden files" if needed.',
    'Navigate: Internal storage → Android → media → com.whatsapp',
    'Open: WhatsApp → Media → .Statuses',
    'Select the .Statuses folder and tap "Use this folder".',
    'Pull down to refresh — statuses appear here.',
    'Keep this app open while browsing WhatsApp for fastest capture.',
  ];

  static const _businessSteps = [
    'Install and open WhatsApp Business (green "B" icon).',
    'View statuses in WhatsApp Business — tap each one.',
    'Come back to this app → Business tab → tap "Grant folder access".',
    'In the file picker, enable "Show hidden files" if needed.',
    'Navigate: Internal storage → Android → media → com.whatsapp.w4b',
    'Open: WhatsApp Business → Media → .Statuses',
    'Select the .Statuses folder and tap "Use this folder".',
    'Pull down to refresh — business statuses appear here.',
    'Regular WhatsApp and Business need separate folder access.',
  ];

  List<String> get tips => const [
        'WhatsApp only caches statuses you have opened.',
        'If someone deletes a status quickly, keep this app open — it scans every 20 seconds.',
        'Contact names are not stored in WhatsApp cache files; time and size are shown instead.',
        'Save to gallery, save in app, or move to vault to keep beyond 24 hours.',
      ];
}
