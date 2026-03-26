class Article {
  final String title;
  final String date;
  final List<String> tags;
  final List<String> categories;
  final String content;
  final String filePath;

  Article({
    required this.title,
    required this.date,
    this.tags = const [],
    this.categories = const [],
    required this.content,
    required this.filePath,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'date': date,
        'tags': tags,
        'categories': categories,
        'content': content,
        'filePath': filePath,
      };

  factory Article.fromJson(Map<String, dynamic> json) => Article(
        title: json['title'] ?? '',
        date: json['date'] ?? '',
        tags: List<String>.from(json['tags'] ?? []),
        categories: List<String>.from(json['categories'] ?? []),
        content: json['content'] ?? '',
        filePath: json['filePath'] ?? '',
      );

  Article copyWith({
    String? title,
    String? date,
    List<String>? tags,
    List<String>? categories,
    String? content,
    String? filePath,
  }) {
    return Article(
      title: title ?? this.title,
      date: date ?? this.date,
      tags: tags ?? this.tags,
      categories: categories ?? this.categories,
      content: content ?? this.content,
      filePath: filePath ?? this.filePath,
    );
  }
}
