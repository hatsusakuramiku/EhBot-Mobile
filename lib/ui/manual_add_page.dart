import 'package:flutter/material.dart';

import '../api/ehbot_api.dart';
import '../api/models.dart';
import 'candidate_detail_page.dart';
import '../media/thumbnail_loader.dart';
import 'error_text.dart';
import 'theme.dart';
import 'widgets/eh_card.dart';

/// 手动添加任务：粘贴 ExHentai / 预览页 / 磁力链接，解析并入队。
class ManualAddPage extends StatefulWidget {
  const ManualAddPage({super.key, required this.api, required this.thumbnails});

  final EhBotApi api;
  final ThumbnailLoader thumbnails;

  @override
  State<ManualAddPage> createState() => _ManualAddPageState();
}

class _ManualAddPageState extends State<ManualAddPage> {
  final TextEditingController _input = TextEditingController();
  bool _busy = false;
  String? _error;
  ManualAddResult? _result;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String url = _input.text.trim();
    if (url.isEmpty) {
      setState(() => _error = '请先粘贴链接。');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final ManualAddResult result = await widget.api.manualAdd(url);
      if (!mounted) {
        return;
      }
      setState(() {
        _result = result;
        _busy = false;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = describeError(error);
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ManualAddResult? result = _result;
    final bool missing = _error != null && _error!.contains('404');
    return Scaffold(
      appBar: AppBar(title: const Text('手动添加任务')),
      body: ListView(
        padding: const EdgeInsets.all(EhSpacing.l),
        children: <Widget>[
          const Text(
            '粘贴 ExHentai 画廊链接、预览链接或磁力链接，自动解析元数据并加入下载队列；'
            '手动添加视为已审批，重复链接会被指出。',
          ),
          const SizedBox(height: EhSpacing.l),
          TextField(
            key: const ValueKey<String>('manual-url'),
            controller: _input,
            minLines: 3,
            maxLines: 5,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: '链接',
              hintText: 'https://exhentai.org/g/... 或 magnet:?xt=urn:btih:...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: EhSpacing.m),
          if (missing)
            EhCard(
              tone: EhCardTone.warning,
              dense: true,
              child: Text(kEndpointMissingHint),
            ),
          if (_error != null && !missing)
            EhCard(tone: EhCardTone.warning, dense: true, child: Text(_error!)),
          if (result != null) ...<Widget>[
            EhCard(
              dense: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    result.isDuplicate ? '这件作品已经在库里' : '已加入下载队列',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (result.message.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(result.message),
                  ],
                ],
              ),
            ),
            if (result.isDuplicate) ...<Widget>[
              const SizedBox(height: EhSpacing.m),
              FilledButton.tonal(
                key: const ValueKey<String>('manual-open-existing'),
                onPressed: () => _openExisting(result.existingCandidateId!),
                child: Text('查看已有候选 #${result.existingCandidateId}'),
              ),
            ],
          ],
          const SizedBox(height: EhSpacing.l),
          FilledButton.icon(
            key: const ValueKey<String>('manual-submit'),
            onPressed: _busy ? null : _submit,
            icon: const Icon(Icons.download_outlined),
            label: Text(_busy ? '解析中…' : '解析并加入下载队列'),
          ),
        ],
      ),
    );
  }

  Future<void> _openExisting(String candidateId) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext _) => CandidateDetailPage(
          api: widget.api,
          thumbnails: widget.thumbnails,
          candidate: Candidate(id: candidateId, title: ''),
        ),
      ),
    );
  }
}
