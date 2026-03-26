import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

/// 图片查看器工具类
class ImageViewer {
  /// 显示图片查看对话框
  static void show(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => _ImageViewerDialog(imageUrl: imageUrl),
    );
  }

  /// 保存网络图片到相册
  static Future<bool> saveToGallery(BuildContext context, String imageUrl) async {
    try {
      // 显示加载提示
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('正在保存图片...')),
        );
      }

      // 下载图片到临时文件
      final dio = Dio();
      final tempDir = await getTemporaryDirectory();
      final fileName = 'donation_${DateTime.now().millisecondsSinceEpoch}.png';
      final filePath = '${tempDir.path}/$fileName';
      
      await dio.download(imageUrl, filePath);

      // 保存到相册
      await Gal.putImage(filePath, album: 'OpenHexo');
      
      // 删除临时文件
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('图片已保存到相册')),
        );
      }
      return true;
    } on GalException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: ${e.type}')),
        );
      }
      return false;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
      return false;
    }
  }
}

/// 图片查看对话框
class _ImageViewerDialog extends StatefulWidget {
  final String imageUrl;

  const _ImageViewerDialog({required this.imageUrl});

  @override
  State<_ImageViewerDialog> createState() => _ImageViewerDialogState();
}

class _ImageViewerDialogState extends State<_ImageViewerDialog> {
  final TransformationController _controller = TransformationController();
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // 图片主体（可缩放）- 允许超出边界
          InteractiveViewer(
            transformationController: _controller,
            minScale: 0.3,
            maxScale: 5.0,
            boundaryMargin: const EdgeInsets.all(double.infinity),
            clipBehavior: Clip.none,
            child: Center(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Image.network(
                  widget.imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                        color: Colors.white,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(
                        Icons.broken_image,
                        size: 64,
                        color: Colors.white54,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          // 顶部工具栏
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.5),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    IconButton(
                      icon: const Icon(Icons.save_alt, color: Colors.white),
                      onPressed: () => ImageViewer.saveToGallery(context, widget.imageUrl),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
