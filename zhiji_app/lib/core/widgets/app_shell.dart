import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

/// 知记应用壳 — Agent 首屏 + 功能抽屉（FAB）
///
/// 设计文档 v4.0: 用户打开即对话。右下角 FAB 弹出 BottomSheet
/// 提供日记、知识库、首页、设置入口。
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _showDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final theme = Theme.of(context);
        final cs = theme.colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 拖动指示条
                Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text("功能", style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                _DrawerItem(
                  icon: Icons.edit_note,
                  label: "写日记",
                  onTap: () {
                    Navigator.of(ctx).pop();
                    context.push("/diary/new");
                  },
                ),
                _DrawerItem(
                  icon: Icons.folder_outlined,
                  label: "知识库",
                  onTap: () {
                    Navigator.of(ctx).pop();
                    context.push("/knowledge");
                  },
                ),
                _DrawerItem(
                  icon: Icons.dashboard_outlined,
                  label: "首页仪表盘",
                  onTap: () {
                    Navigator.of(ctx).pop();
                    context.push("/home");
                  },
                ),
                _DrawerItem(
                  icon: Icons.settings_outlined,
                  label: "设置",
                  onTap: () {
                    Navigator.of(ctx).pop();
                    context.push("/settings");
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDrawer(context),
        tooltip: "功能",
        child: const Icon(Icons.grid_view),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}
