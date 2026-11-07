class OnboardingModel {
  const OnboardingModel({
    required this.role,
    required this.onboardingCompleted,
    required this.onboardingStep,
  });

  final String role;
  final bool onboardingCompleted;
  final int onboardingStep;

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'onboardingCompleted': onboardingCompleted,
      'onboardingStep': onboardingStep,
    };
  }
}