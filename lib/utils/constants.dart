/// Application-wide constants including academic topics and seed question data.
class AppConstants {
  AppConstants._();

  /// Default supported academic topics.
  static const List<String> topics = [
    'Operating Systems',
    'Database Management',
    'Computer Networks',
    'Mathematics',
    'Physics',
    'Design & Analysis of Algorithms',
    'Object Oriented Programming',
    'Web Programming',
    'Computer Organization & Architecture',
    'Microprocessors & Microcontrollers',
    'Other',
  ];

  static List<String> get academicTopics => topics;

  static List<({String topic, String question, String answer})> get initialQuestions =>
      seedQuestions.map((q) => (
        topic: q['topic'] ?? '',
        question: q['question'] ?? '',
        answer: q['answer'] ?? '',
      )).toList();

  /// Initial seed questions populated on first database creation.
  /// Contains at least 4 questions with comprehensive answers for each of the first 5 topics.
  static const List<Map<String, String>> seedQuestions = [
    // --- Operating Systems ---
    {
      'topic': 'Operating Systems',
      'question': 'What is the primary difference between a process and a thread?',
      'answer':
          'A process is an executing program with its own dedicated memory address space, file descriptors, and system resources. A thread is a lightweight unit of execution within a process that shares the parent process\'s memory space, code, and data sections while maintaining its own program counter, registers, and stack.',
    },
    {
      'topic': 'Operating Systems',
      'question': 'What are Coffman\'s four necessary conditions for deadlock to occur?',
      'answer':
          'The four Coffman conditions are:\n1. Mutual Exclusion: At least one resource must be held in a non-shareable mode.\n2. Hold and Wait: A process holds at least one resource while waiting to acquire additional resources held by other processes.\n3. No Preemption: Resources cannot be forcibly taken from a process holding them; they must be released voluntarily.\n4. Circular Wait: A closed chain of processes exists where each process holds resources needed by the next process in the chain.',
    },
    {
      'topic': 'Operating Systems',
      'question': 'How does virtual memory paging work, and what is a page fault?',
      'answer':
          'Virtual memory divides logical memory into fixed-size blocks called pages, and physical memory into corresponding blocks called page frames. The Memory Management Unit (MMU) translates logical page addresses to physical frame addresses via a page table. A page fault is a hardware interrupt triggered when an executing program accesses a page that is not currently mapped into physical RAM, causing the OS to retrieve it from secondary storage (swap/paging space).',
    },
    {
      'topic': 'Operating Systems',
      'question': 'What is the difference between a binary semaphore and a mutex?',
      'answer':
          'A mutex (mutual exclusion lock) has ownership semantics: only the thread that locked the mutex can unlock it. A binary semaphore is a signaling mechanism with an integer value (0 or 1) that can be signaled (posted/released) by any thread, not just the thread that acquired (waited on) it.',
    },

    // --- Database Management ---
    {
      'topic': 'Database Management',
      'question': 'Explain the ACID properties in database transaction management.',
      'answer':
          'ACID stands for:\n• Atomicity: An entire transaction completes successfully, or all its changes are completely rolled back ("all or nothing").\n• Consistency: Transactions transition the database from one valid state to another, preserving all schema constraints.\n• Isolation: Concurrent execution of transactions yields the same state as if they were executed serially.\n• Durability: Once a transaction commits, its changes survive system crashes or power failures.',
    },
    {
      'topic': 'Database Management',
      'question': 'What are 1NF, 2NF, and 3NF in relational database normalization?',
      'answer':
          '• 1NF (First Normal Form): All column values must be atomic (no repeating groups or arrays) and each row must be uniquely identifiable.\n• 2NF (Second Normal Form): Meets 1NF, and all non-key attributes are fully functionally dependent on the entire primary key (no partial key dependencies).\n• 3NF (Third Normal Form): Meets 2NF, and no non-key attribute is transitively dependent on the primary key (no transitive dependencies).',
    },
    {
      'topic': 'Database Management',
      'question': 'What is the difference between a Primary Key and a Unique Key constraint?',
      'answer':
          'A Primary Key uniquely identifies each row in a table, cannot contain NULL values, and each table can have at most one primary key. A Unique Key enforces uniqueness across rows for specified columns, can permit one or more NULL values (depending on the SQL dialect), and a table can possess multiple unique key constraints.',
    },
    {
      'topic': 'Database Management',
      'question': 'What is a B-Tree index, and why is it preferred for relational database lookups?',
      'answer':
          'A B-Tree (balanced tree) index is a self-balancing search tree data structure that maintains sorted data and allows searches, sequential access, insertions, and deletions in logarithmic time (O(log n)). It minimizes disk I/O reads by grouping multiple keys per tree node, matching operating system page block sizes.',
    },

    // --- Computer Networks ---
    {
      'topic': 'Computer Networks',
      'question': 'Compare the 7-layer OSI Reference Model with the 4-layer TCP/IP Model.',
      'answer':
          '• OSI Model (Theoretical): Physical, Data Link, Network, Transport, Session, Presentation, Application.\n• TCP/IP Model (Practical implementation):\n  1. Network Access (combines Physical & Data Link)\n  2. Internet (corresponds to Network layer; IP, ICMP)\n  3. Transport (TCP, UDP)\n  4. Application (combines Session, Presentation, Application; HTTP, DNS, SSH, FTP).',
    },
    {
      'topic': 'Computer Networks',
      'question': 'Describe the TCP Three-Way Handshake process for establishing a connection.',
      'answer':
          'TCP connection establishment uses three segments:\n1. SYN: The client generates an Initial Sequence Number (ISN_c) and sends a segment with SYN flag set to the server.\n2. SYN-ACK: The server receives SYN, responds with its own ISN_s, and acknowledges the client with ACK = ISN_c + 1.\n3. ACK: The client sends an ACK segment with ACK = ISN_s + 1. The connection is now established and data transmission begins.',
    },
    {
      'topic': 'Computer Networks',
      'question': 'How does Domain Name System (DNS) resolution resolve a domain to an IP address?',
      'answer':
          'When a user queries a domain name:\n1. The client checks local browser cache and OS hosts cache.\n2. If missed, it queries the recursive DNS resolver (ISP or 8.8.8.8).\n3. The recursive resolver asks a Root Nameserver (which directs to the TLD nameserver, e.g. .com).\n4. The TLD nameserver directs to the domain\'s Authoritative Nameserver.\n5. The authoritative nameserver returns the IP address (A/AAAA record) to the resolver, which caches and returns it to the client.',
    },
    {
      'topic': 'Computer Networks',
      'question': 'What are the key technical differences between IPv4 and IPv6?',
      'answer':
          '• Address Space: IPv4 uses 32-bit addresses (~4.3 billion addresses in dotted decimal notation, e.g., 192.168.1.1). IPv6 uses 128-bit addresses (~3.4 x 10^38 addresses in hexadecimal notation separated by colons).\n• Header Complexity: IPv6 has a streamlined 40-byte fixed header without checksums, accelerating router packet processing.\n• Configuration: IPv6 supports Stateless Address Autoconfiguration (SLAAC) and native IPSec encryption.',
    },

    // --- Mathematics ---
    {
      'topic': 'Mathematics',
      'question': 'What are eigenvalues and eigenvectors of a square matrix A?',
      'answer':
          'An eigenvector v of a square matrix A is a non-zero vector that, when multiplied by A, yields a scalar multiple of itself: A*v = λ*v. The scalar λ is known as the eigenvalue corresponding to eigenvector v. Eigenvalues are computed by solving the characteristic equation: det(A - λ*I) = 0.',
    },
    {
      'topic': 'Mathematics',
      'question': 'State Bayes\' Theorem and explain each component term.',
      'answer':
          'Bayes\' Theorem states: P(A|B) = [P(B|A) * P(A)] / P(B)\n• P(A|B): Posterior probability of event A occurring given evidence B has occurred.\n• P(B|A): Likelihood of observing evidence B given hypothesis A is true.\n• P(A): Prior probability of hypothesis A before observing evidence.\n• P(B): Marginal probability of observing evidence B.',
    },
    {
      'topic': 'Mathematics',
      'question': 'What is the rank of a matrix and how is it related to the nullity?',
      'answer':
          'The rank of a matrix is the maximum number of linearly independent row or column vectors in the matrix, indicating the dimension of its column/row space. According to the Rank-Nullity Theorem for an m x n matrix representing linear transformation T: Rank(T) + Nullity(T) = n (the number of columns / dimension of the domain).',
    },
    {
      'topic': 'Mathematics',
      'question': 'What does the Central Limit Theorem (CLT) state in probability and statistics?',
      'answer':
          'The Central Limit Theorem states that the distribution of sample means of independent and identically distributed (i.i.d.) random variables approaches a normal (Gaussian) distribution as sample size n increases (typically n >= 30), regardless of the shape of the underlying population distribution, provided the population has a finite variance.',
    },

    // --- Physics ---
    {
      'topic': 'Physics',
      'question': 'Explain the Photoelectric Effect and state Einstein\'s Photoelectric Equation.',
      'answer':
          'The photoelectric effect is the emission of electrons from a metal surface when electromagnetic radiation of sufficiently high frequency (above the threshold frequency f_0) strikes it. Einstein\'s photoelectric equation is: E_k(max) = h*f - Φ, where E_k(max) is the maximum kinetic energy of emitted photoelectrons, h is Planck\'s constant, f is incident light frequency, and Φ (h*f_0) is the metal work function.',
    },
    {
      'topic': 'Physics',
      'question': 'State Heisenberg\'s Uncertainty Principle and its physical implications.',
      'answer':
          'Heisenberg\'s Uncertainty Principle states that it is fundamentally impossible to simultaneously determine both the exact position (x) and exact momentum (p) of a quantum particle with arbitrary precision: Δx * Δp >= ħ / 2, where ħ = h / (2*π). This is not an experimental measurement limitation, but an inherent wave-particle property of quantum systems.',
    },
    {
      'topic': 'Physics',
      'question': 'What is Gauss\'s Law in electrostatics and what is its integral form?',
      'answer':
          'Gauss\'s Law states that the total electric flux Φ_E through any closed Gaussian surface is equal to the net charge Q_enclosed enclosed within the surface divided by the electric permittivity of free space ε_0: ∮ E · dA = Q_enclosed / ε_0. It provides an efficient method to calculate electric fields in symmetrically charged systems.',
    },
    {
      'topic': 'Physics',
      'question': 'Summarize the four fundamental Maxwell\'s Equations of electromagnetism.',
      'answer':
          'The four Maxwell\'s equations describe how electric and magnetic fields interact with matter and each other:\n1. Gauss\'s Law for Electricity: ∇ · E = ρ / ε_0 (Electric charges generate diverging electric fields).\n2. Gauss\'s Law for Magnetism: ∇ · B = 0 (No magnetic monopoles exist).\n3. Faraday\'s Law of Induction: ∇ × E = -∂B/∂t (Time-varying magnetic fields produce circulating electric fields).\n4. Ampere-Maxwell Law: ∇ × B = μ_0*J + μ_0*ε_0*(∂E/∂t) (Electric currents and changing electric fields produce magnetic fields).',
    },
  ];
}

