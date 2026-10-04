import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ternak_cibeusi_app/database/schema.dart';

/// SQLite in-memory dengan skema aplikasi (sama dengan repository_test.dart).
Future<Database> openMemoryDb() => databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: dbVersion,
        onConfigure: configureDb,
        onCreate: createSchema,
        onUpgrade: upgradeSchema,
        singleInstance: false,
      ),
    );
