/// 情绪枚举（复用原型的情绪系统）
enum Emotion {
  happy('😊', '开心'),
  calm('😌', '平静'),
  sad('😢', '难过'),
  excited('🤩', '兴奋'),
  tired('😮‍💨', '疲惫'),
  grateful('🙏', '感恩'),
  anxious('😰', '焦虑'),
  reflective('🤔', '反思');

  const Emotion(this.emoji, this.label);
  final String emoji;
  final String label;
}
