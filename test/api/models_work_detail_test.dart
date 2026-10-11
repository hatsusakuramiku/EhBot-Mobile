import 'package:ehbot_mobile/api/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('WorkDetail.fromJson: 缺事件时空 actions', () {
    final WorkDetail detail = WorkDetail.fromJson(<String, Object?>{
      'candidate_id': '11',
      'title': 't',
    });
    expect(detail.actions, isEmpty);
    expect(detail.can('approve'), isFalse);
    expect(detail.can('reject'), isFalse);
  });

  test('WorkDetail.fromJson: 缺 cover 时为 null', () {
    final WorkDetail detail = WorkDetail.fromJson(<String, Object?>{
      'candidate_id': '11',
    });
    expect(detail.cover, isNull);
  });

  test('WorkDetail.fromJson: cover.hash 不为空时构造 CoverRef', () {
    final WorkDetail detail = WorkDetail.fromJson(<String, Object?>{
      'candidate_id': '11',
      'cover': <String, Object?>{'hash': 'h'},
    });
    expect(detail.cover, isNotNull);
    expect(detail.cover!.hash, 'h');
  });

  test('WorkDetail.fromJson: 文本字段优先于 actions 中的同名按钮', () {
    final WorkDetail detail = WorkDetail.fromJson(<String, Object?>{
      'candidate_id': '11',
      'actions': <String, Object?>{
        'approve': true,
        'repack': true,
        'delete_files': false,
      },
    });
    expect(detail.can('approve'), isTrue);
    expect(detail.can('repack'), isTrue);
    expect(detail.can('delete_files'), isFalse);
  });

  test('Summary.connections + ConnectionInfo: 返回空会话表', () {
    final Summary s = Summary.fromJson(<String, Object?>{
      'connections': <String, Object?>{
        'telegram': <String, Object?>{
          'label': 'Telegram',
          'state': <String, Object?>{'code': 'ok', 'label': ''},
        },
      },
    });
    expect(s.connections.length, 1);
    expect(s.connections['telegram']!.label, 'Telegram');
  });
}
