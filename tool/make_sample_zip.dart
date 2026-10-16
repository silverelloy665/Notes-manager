import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';

void main() {
  final archive = Archive();

  // Helper to add file to archive
  void addFile(String path, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  // Subject 1: Operating Systems
  // Unit 1 - Process Management
  addFile(
    'Operating Systems/Unit 1 - Process Management/notes/01_cpu_scheduling.txt',
    'CPU Scheduling Algorithms:\n1. First-Come, First-Served (FCFS)\n2. Shortest Job First (SJF)\n3. Round Robin (RR)\n4. Priority Scheduling\n\nContext Switching Overhead:\nTime taken to save state of old process and load state of new process.',
  );
  addFile(
    'Operating Systems/Unit 1 - Process Management/practicals/exp1_fork.c',
    '#include <stdio.h>\n#include <unistd.h>\n\nint main() {\n    pid_t pid = fork();\n    if (pid == 0) {\n        printf("Child process: PID=%d\\n", getpid());\n    } else {\n        printf("Parent process: PID=%d\\n", getpid());\n    }\n    return 0;\n}',
  );
  addFile(
    'Operating Systems/Unit 1 - Process Management/questions.json',
    json.encode([
      {
        'question': 'What is the purpose of the Translation Lookaside Buffer (TLB)?',
        'answer': 'The TLB is a high-speed associative hardware cache storing recent virtual-to-physical address translations to accelerate memory access without repeated page table lookups.'
      },
      {
        'question': 'Distinguish between Preemptive and Non-Preemptive scheduling.',
        'answer': 'Preemptive scheduling forcibly interrupts a running process when a higher-priority task arrives (e.g. Round Robin), whereas non-preemptive allows a process to run until it voluntarily yields or terminates.'
      }
    ]),
  );

  // Unit 2 - Memory Management
  addFile(
    'Operating Systems/Unit 2 - Memory Management/notes/02_virtual_memory.md',
    '# Virtual Memory & Paging\n\n- **Paging**: Fixed-size memory blocks (pages and frames).\n- **Segmentation**: Variable-size logical blocks.\n- **Page Fault**: Interrupt generated when a requested page is not in physical RAM.',
  );
  addFile(
    'Operating Systems/Unit 2 - Memory Management/practicals/exp2_lru_paging.cpp',
    '#include <iostream>\n#include <vector>\n#include <unordered_map>\nusing namespace std;\n\nint main() {\n    cout << "LRU Page Replacement Algorithm Simulation\\n";\n    return 0;\n}',
  );

  // Subject 2: Database Management
  // Unit 1 - Relational Model
  addFile(
    'Database Management/Unit 1 - Relational Model/notes/01_er_modeling.txt',
    'Entity-Relationship Concepts:\n- Entities: Real-world objects with attributes.\n- Relationships: Cardinality (1:1, 1:N, M:N).\n- Keys: Primary Key, Foreign Key, Candidate Key.',
  );
  addFile(
    'Database Management/Unit 1 - Relational Model/practicals/exp1_ddl_dml.sql',
    '-- SQL DDL and DML Practical\nCREATE TABLE Students (\n    student_id INT PRIMARY KEY,\n    name VARCHAR(100) NOT NULL,\n    email VARCHAR(100) UNIQUE\n);\n\nINSERT INTO Students VALUES (1, "Aarush", "aarush@test.com");\nSELECT * FROM Students;',
  );

  // Unit 2 - Normalization & Transactions
  addFile(
    'Database Management/Unit 2 - Normalization and Transactions/notes/02_acid_properties.md',
    '# ACID Properties in DBMS\n\n1. **Atomicity**: All or nothing execution.\n2. **Consistency**: Database invariants preserved.\n3. **Isolation**: Concurrent transactions execute as if serialized.\n4. **Durability**: Committed changes persist across system crashes.',
  );
  addFile(
    'Database Management/Unit 2 - Normalization and Transactions/practicals/exp2_transactions.sql',
    '-- Transaction Control Commands\nBEGIN TRANSACTION;\nUPDATE Accounts SET balance = balance - 500 WHERE id = 101;\nUPDATE Accounts SET balance = balance + 500 WHERE id = 102;\nCOMMIT;',
  );

  final zipBytes = ZipEncoder().encode(archive);
  if (zipBytes != null) {
    final outputFile = File('sample_study_material.zip');
    outputFile.writeAsBytesSync(zipBytes);
    // ignore: avoid_print
    print('Generated sample_study_material.zip (${zipBytes.length} bytes)');
  }
}
