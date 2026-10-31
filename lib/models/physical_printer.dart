import 'saved_printer.dart';

/// Connection belongs to the hardware, never to a logical destination.
class PhysicalPrinter {
  const PhysicalPrinter(
      {required this.physicalPrinterId,
      required this.deviceName,
      required this.transport,
      required this.address,
      this.port = 9100,
      this.verifiedCapabilities = const {}});

  final String physicalPrinterId, deviceName, address;
  final PrinterLinkType transport;
  final int port;

  /// Only capabilities explicitly verified on hardware belong here.
  final Map<String, dynamic> verifiedCapabilities;

  Map<String, dynamic> toJson() => {
        'physicalPrinterId': physicalPrinterId,
        'deviceName': deviceName,
        'type': transport.name,
        'address': address,
        'port': port,
        'verifiedCapabilities': verifiedCapabilities,
      };
}
