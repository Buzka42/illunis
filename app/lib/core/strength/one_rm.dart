/// Estimated 1RM. Store both; the dashboard shows Epley.
/// Only defined for 1–10 reps — beyond that the formulae invent weight.
library;

double? epley1rm(double weightKg, int reps) {
  if (reps < 1 || reps > 10 || weightKg <= 0) return null;
  if (reps == 1) return weightKg;
  return weightKg * (1 + reps / 30);
}

double? brzycki1rm(double weightKg, int reps) {
  if (reps < 1 || reps > 10 || weightKg <= 0 || reps >= 37) return null;
  if (reps == 1) return weightKg;
  return weightKg * 36 / (37 - reps);
}
