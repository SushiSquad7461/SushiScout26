import 'package:mockito/annotations.dart';
import 'package:frontend/data/repositories/hybrid_repository.dart';
import 'package:frontend/data/repositories/firestore_repository.dart';
import 'package:frontend/data/local/database/app_database.dart';

@GenerateMocks([HybridRepository, FirestoreRepository, AppDatabase])
void main() {}
