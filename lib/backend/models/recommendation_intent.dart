class RecommendationIntent {
  const RecommendationIntent({
    required this.originalText,
    required this.keywords,
    required this.constraints,
  });

  final String originalText;
  final List<String> keywords;
  final List<String> constraints;
}
