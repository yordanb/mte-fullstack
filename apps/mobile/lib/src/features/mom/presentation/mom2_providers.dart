import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mte_data_center/src/core/network/dio_client.dart' show apiMessage;

import '../data/mom2_api.dart';
import '../domain/mom2_models.dart';

/// Daftar meeting MOM 2 (urut tanggal turun — server yang mengurutkan).
final mom2ListProvider = FutureProvider<List<Mom2Meeting>>((ref) async {
  try {
    return await ref.watch(mom2ApiProvider).listMeetings();
  } catch (e) {
    throw apiMessage(e);
  }
});

/// Detail meeting + item (family per id meeting).
final mom2DetailProvider =
    FutureProvider.family<Mom2MeetingDetail, int>((ref, id) async {
  try {
    return await ref.watch(mom2ApiProvider).getMeeting(id);
  } catch (e) {
    throw apiMessage(e);
  }
});
