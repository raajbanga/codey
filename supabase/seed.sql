-- Content for the content_* tables (migration 20261116000000_content.sql),
-- exported from the live project on 2026-11-15: 8 topics, 192 questions,
-- 25 coding exercises, 15 starter decks with 174 cards.
-- Run once after the migrations (SQL editor, or psql -f supabase/seed.sql).
-- Safe to re-run: rows are upserted by id, so edits made in the dashboard
-- are overwritten with these values and nothing else is touched.
-- The app downloads these tables at launch; without them it keeps using
-- the bundled JSON in codey/Resources.

begin;

-- content_topics: 8 rows
insert into public.content_topics (id, title, summary, icon_name, sort_index) values
  ('topic-data-structures', 'Data Structures', 'Arrays, linked lists, trees, hash maps, and the trade-offs between them.', 'square.stack.3d.up.fill', 0),
  ('topic-algorithms', 'Algorithms', 'Sorting, searching, recursion, and divide-and-conquer strategies.', 'function', 1),
  ('topic-os-basics', 'OS Basics', 'Processes, threads, memory management, and scheduling fundamentals.', 'cpu', 2),
  ('topic-databases', 'Databases', 'Relational models, SQL, indexing, and transaction basics.', 'cylinder.split.1x2.fill', 3),
  ('topic-oop', 'Object-Oriented Programming', 'Classes, objects, inheritance, polymorphism, and design principles.', 'cube.transparent', 4),
  ('topic-networking', 'Networking', 'How data moves: IP, TCP/UDP, HTTP, DNS, and TLS.', 'network', 5),
  ('topic-swift', 'Swift Basics', 'Optionals, value vs reference types, closures, protocols, and concurrency.', 'swift', 6),
  ('topic-python', 'Python Basics', 'Lists, dicts, comprehensions, functions, and Python''s data model.', 'chevron.left.forwardslash.chevron.right', 7)
on conflict (id) do update set title = excluded.title, summary = excluded.summary, icon_name = excluded.icon_name, sort_index = excluded.sort_index;

-- content_questions: 192 rows
insert into public.content_questions (id, topic_id, prompt, options, correct_option_index, explanation, difficulty, sort_index) values
  ('q-ds-001', 'topic-data-structures', 'What is the average-case time complexity of a hash table lookup?', array['O(1)', 'O(n)', 'O(log n)', 'O(n^2)']::text[], 0, 'With a good hash function and low load factor, lookups are amortized O(1). Worst case (many collisions) degrades to O(n).', 'easy', 0),
  ('q-ds-002', 'topic-data-structures', 'What is the average time complexity of accessing an element in a dynamic array by index?', array['O(1)', 'O(log n)', 'O(n)', 'O(n log n)']::text[], 0, 'Dynamic arrays support constant-time random access via index.', 'easy', 1),
  ('q-ds-003', 'topic-data-structures', 'Which data structure uses FIFO (First In, First Out) ordering?', array['Stack', 'Queue', 'Binary Tree', 'Hash Map']::text[], 1, 'Queues process elements in the order they were enqueued.', 'easy', 2),
  ('q-ds-004', 'topic-data-structures', 'What is the worst-case time complexity of lookup in a hash table with many collisions?', array['O(1)', 'O(log n)', 'O(n)', 'O(n²)']::text[], 2, 'With poor hashing or many collisions, lookup degrades to linear scan.', 'medium', 3),
  ('q-ds-005', 'topic-data-structures', 'In a balanced binary search tree, what is the time complexity of search?', array['O(1)', 'O(log n)', 'O(n)', 'O(n log n)']::text[], 1, 'A balanced BST halves the search space at each level, giving O(log n) search.', 'medium', 4),
  ('q-ds-006', 'topic-data-structures', 'Which data structure uses LIFO (Last In, First Out) ordering?', array['Queue', 'Stack', 'Heap', 'Deque']::text[], 1, 'Stacks push and pop from the same end, so the most recently added element is removed first.', 'easy', 5),
  ('q-ds-007', 'topic-data-structures', 'What is the time complexity of inserting at the head of a singly linked list (given a pointer to the head)?', array['O(1)', 'O(log n)', 'O(n)', 'O(n log n)']::text[], 0, 'Head insertion only requires updating a few pointers, regardless of list size.', 'medium', 6),
  ('q-ds-008', 'topic-data-structures', 'What property does a min-heap maintain?', array['Every parent is smaller than or equal to its children', 'Every parent is larger than or equal to its children', 'The tree is always perfectly balanced', 'All leaves are at the same depth']::text[], 0, 'In a min-heap, the smallest element is at the root and each parent is ≤ its children — ideal for priority queues.', 'medium', 7),
  ('q-ds-009', 'topic-data-structures', 'For a sparse graph with few edges, which representation is typically more space-efficient?', array['Adjacency matrix', 'Adjacency list', 'Incidence matrix', 'Edge list with full vertex pairs']::text[], 1, 'Adjacency lists store only existing edges, while an adjacency matrix uses O(V²) space regardless of edge count.', 'medium', 8),
  ('q-ds-010', 'topic-data-structures', 'When is a hash set preferred over a sorted array for lookups?', array['When you need ordered traversal', 'When you need average O(1) membership checks on unsorted data', 'When memory must be minimized at all costs', 'When duplicate values must be preserved in order']::text[], 1, 'Hash sets provide fast average-case contains checks without maintaining sorted order.', 'medium', 9),
  ('q-ds-011', 'topic-data-structures', 'Why is a linked list often preferred over a dynamic array for frequent insertions at the front?', array['Linked lists have O(1) random access', 'Linked lists avoid shifting all existing elements on each front insert', 'Linked lists always use less memory than arrays', 'Linked lists guarantee cache-friendly memory layout']::text[], 1, 'Array front inserts require shifting O(n) elements; linked list head inserts are O(1).', 'easy', 10),
  ('q-ds-012', 'topic-data-structures', 'Why are B-trees commonly used in database indexes?', array['They guarantee O(1) lookup in all cases', 'They stay balanced and minimize disk reads with high branching factor', 'They store data only in leaf nodes with no internal keys', 'They are simpler to implement than hash tables']::text[], 1, 'B-trees are shallow and disk-friendly, reducing I/O compared to binary tree structures.', 'hard', 11),
  ('q-algo-001', 'topic-algorithms', 'What is the time complexity of binary search on a sorted array?', array['O(1)', 'O(log n)', 'O(n)', 'O(n log n)']::text[], 1, 'Binary search halves the search space each step, giving O(log n).', 'easy', 12),
  ('q-algo-002', 'topic-algorithms', 'Which sorting algorithm has a best-case time complexity of O(n)?', array['Merge Sort', 'Quick Sort', 'Insertion Sort', 'Heap Sort']::text[], 2, 'Insertion sort runs in O(n) when the input is already nearly sorted.', 'medium', 13),
  ('q-algo-003', 'topic-algorithms', 'What does the Master Theorem help analyze?', array['Graph traversal order', 'Divide-and-conquer recurrence relations', 'Hash collision resolution', 'Memory allocation patterns']::text[], 1, 'The Master Theorem provides closed-form solutions for common recurrences.', 'hard', 14),
  ('q-algo-004', 'topic-algorithms', 'Which algorithm design paradigm breaks a problem into independent subproblems, solves them recursively, and combines results?', array['Greedy', 'Dynamic Programming', 'Divide and Conquer', 'Backtracking']::text[], 2, 'Divide and conquer splits the problem, solves subproblems independently, and merges results.', 'easy', 15),
  ('q-algo-005', 'topic-algorithms', 'What is the average-case time complexity of Quick Sort?', array['O(n)', 'O(n log n)', 'O(n²)', 'O(log n)']::text[], 1, 'Quick Sort averages O(n log n) with good pivot selection, though worst case is O(n²).', 'medium', 16),
  ('q-algo-006', 'topic-algorithms', 'What is the time and auxiliary space complexity of Merge Sort?', array['O(n log n) time, O(1) space', 'O(n log n) time, O(n) space', 'O(n²) time, O(n) space', 'O(n) time, O(log n) space']::text[], 1, 'Merge Sort always runs in O(n log n) but requires O(n) extra space for merging.', 'medium', 17),
  ('q-algo-007', 'topic-algorithms', 'Which traversal uses a queue and explores neighbors level by level?', array['Depth-First Search (DFS)', 'Breadth-First Search (BFS)', 'Dijkstra''s algorithm', 'Topological sort']::text[], 1, 'BFS processes nodes in order of increasing distance from the start, using a FIFO queue.', 'easy', 18),
  ('q-algo-008', 'topic-algorithms', 'What is the key difference between greedy algorithms and dynamic programming?', array['Greedy always uses recursion; DP never does', 'Greedy makes locally optimal choices without revisiting; DP solves overlapping subproblems with stored results', 'Greedy is only for graphs; DP is only for arrays', 'Greedy guarantees optimal solutions; DP does not']::text[], 1, 'Greedy commits to the best immediate choice; DP builds optimal solutions by caching subproblem answers.', 'hard', 19),
  ('q-algo-009', 'topic-algorithms', 'What problem does Dijkstra''s algorithm solve?', array['Finding a minimum spanning tree', 'Finding shortest paths from a source in a graph with non-negative edge weights', 'Detecting cycles in a directed graph', 'Sorting vertices in topological order']::text[], 1, 'Dijkstra''s algorithm computes shortest paths from a single source when edge weights are non-negative.', 'medium', 20),
  ('q-algo-010', 'topic-algorithms', 'The two-pointer technique is commonly used on:', array['Unsorted arrays to find pairs meeting a condition in linear time', 'Binary trees to compute height', 'Hash tables to resolve collisions', 'Graphs to find articulation points']::text[], 0, 'Two pointers on a sorted (or appropriately structured) array can solve many pair/sum problems in O(n).', 'medium', 21),
  ('q-algo-011', 'topic-algorithms', 'What is the purpose of a base case in recursion?', array['To improve average-case performance', 'To stop the recursion and prevent infinite self-calls', 'To allocate heap memory for the call stack', 'To convert the algorithm from top-down to bottom-up']::text[], 1, 'Without a base case, recursive calls never terminate.', 'easy', 22),
  ('q-algo-012', 'topic-algorithms', 'A sorting algorithm is ''stable'' if:', array['It always runs in O(n log n) time', 'It preserves the relative order of equal elements', 'It uses O(1) extra space', 'It never compares adjacent elements']::text[], 1, 'Stability matters when sorting records by multiple keys — equal primary keys keep their original order.', 'hard', 23),
  ('q-os-001', 'topic-os-basics', 'What is the main difference between a process and a thread?', array['Processes share memory; threads do not', 'Threads share a process''s memory space; processes do not', 'Processes are faster than threads', 'Threads require more memory than processes']::text[], 1, 'Threads within the same process share address space; processes have isolated memory.', 'easy', 24),
  ('q-os-002', 'topic-os-basics', 'Which scheduling algorithm can cause starvation?', array['Round Robin', 'First-Come First-Served', 'Priority Scheduling', 'FIFO']::text[], 2, 'Low-priority processes may never run if higher-priority work keeps arriving.', 'medium', 25),
  ('q-os-003', 'topic-os-basics', 'What does virtual memory allow an OS to do?', array['Run programs faster than physical RAM allows', 'Give each process the illusion of a large, private address space', 'Eliminate the need for a hard drive', 'Share CPU time equally among processes']::text[], 1, 'Virtual memory maps process addresses to physical RAM or disk, giving each process its own address space.', 'medium', 26),
  ('q-os-004', 'topic-os-basics', 'A deadlock requires which of the following conditions (Coffman conditions)?', array['Preemption, timeout, and priority inversion', 'Mutual exclusion, hold and wait, no preemption, circular wait', 'Paging, segmentation, and swapping', 'Caching, buffering, and spooling']::text[], 1, 'All four Coffman conditions must hold simultaneously for deadlock to occur.', 'hard', 27),
  ('q-os-005', 'topic-os-basics', 'What is context switching?', array['Switching between user mode and kernel mode', 'Saving the state of one process/thread and loading another''s', 'Moving data from disk to RAM', 'Changing the priority of a running process']::text[], 1, 'Context switching saves the current execution state and restores another''s so the CPU can run a different task.', 'easy', 28),
  ('q-os-006', 'topic-os-basics', 'What is the main purpose of kernel mode?', array['Run user applications with fewer permissions', 'Execute privileged operations like I/O and memory management', 'Display the graphical user interface', 'Compile source code into machine instructions']::text[], 1, 'Kernel mode allows the OS to perform protected hardware and system operations unsafe for user mode.', 'easy', 29),
  ('q-os-007', 'topic-os-basics', 'How does paging differ from segmentation?', array['Paging uses fixed-size blocks; segmentation uses variable-size logical segments', 'Paging is only used for cache; segmentation is only for disk', 'Paging requires more programmer effort than segmentation', 'Segmentation eliminates the need for a page table']::text[], 0, 'Paging splits memory into equal pages; segmentation divides a program into logical units like code, stack, and heap.', 'hard', 30),
  ('q-os-008', 'topic-os-basics', 'In Round Robin scheduling, what determines how long each process runs before being preempted?', array['Priority level', 'Time quantum', 'Process arrival order only', 'Available physical memory']::text[], 1, 'Each process gets a fixed time slice (quantum); when it expires, the CPU moves to the next ready process.', 'medium', 31),
  ('q-os-009', 'topic-os-basics', 'What is the primary difference between a mutex and a semaphore?', array['A mutex allows multiple threads in; a semaphore allows only one', 'A mutex is typically binary (one owner); a semaphore can permit a counted number of concurrent accesses', 'A mutex is for processes only; a semaphore is for threads only', 'A mutex prevents deadlock; a semaphore causes deadlock']::text[], 1, 'Mutexes enforce mutual exclusion for one holder; counting semaphores can allow N simultaneous accesses.', 'medium', 32),
  ('q-os-010', 'topic-os-basics', 'What is thrashing?', array['When the CPU runs at 100% utilization efficiently', 'When excessive paging causes the system to spend most time on disk I/O instead of useful work', 'When all processes finish simultaneously', 'When a thread exits before acquiring a lock']::text[], 1, 'Thrashing occurs when there is insufficient physical memory and constant page faults dominate performance.', 'medium', 33),
  ('q-os-011', 'topic-os-basics', 'Why does a program use a system call?', array['To bypass the OS entirely for faster I/O', 'To request a privileged service from the operating system kernel', 'To allocate stack space for local variables', 'To convert high-level code to bytecode']::text[], 1, 'System calls are the controlled interface through which user programs ask the kernel to perform protected operations.', 'easy', 34),
  ('q-os-012', 'topic-os-basics', 'The producer-consumer problem primarily illustrates the need for:', array['Faster CPU clock speeds', 'Synchronization between threads sharing a bounded buffer', 'Virtual memory address translation', 'Static linking of libraries']::text[], 1, 'Producers and consumers must coordinate access to shared buffer space to avoid race conditions and overflow/underflow.', 'hard', 35),
  ('q-db-001', 'topic-databases', 'Which SQL clause filters rows before grouping?', array['HAVING', 'WHERE', 'ORDER BY', 'GROUP BY']::text[], 1, 'WHERE filters rows before aggregation; HAVING filters after GROUP BY.', 'easy', 36),
  ('q-db-002', 'topic-databases', 'What property ensures a transaction is all-or-nothing?', array['Consistency', 'Isolation', 'Atomicity', 'Durability']::text[], 2, 'Atomicity guarantees that either all operations in a transaction commit or none do.', 'easy', 37),
  ('q-db-003', 'topic-databases', 'What is the primary purpose of a database index?', array['To enforce referential integrity', 'To speed up data retrieval at the cost of extra storage and write overhead', 'To encrypt sensitive columns', 'To normalize tables to 3NF']::text[], 1, 'Indexes create lookup structures (like B-trees) that reduce query scan time.', 'medium', 38),
  ('q-db-004', 'topic-databases', 'In a relational database, a foreign key is used to:', array['Uniquely identify each row in a table', 'Reference a primary key in another table to enforce relationships', 'Index a column for faster search', 'Encrypt a column''s values']::text[], 1, 'Foreign keys link rows across tables and enforce referential integrity.', 'easy', 39),
  ('q-db-005', 'topic-databases', 'Which normal form eliminates partial dependencies on a composite primary key?', array['1NF', '2NF', '3NF', 'BCNF']::text[], 1, 'Second Normal Form (2NF) removes partial dependencies — non-key attributes must depend on the entire primary key.', 'hard', 40),
  ('q-db-006', 'topic-databases', 'What does an INNER JOIN return?', array['All rows from both tables regardless of match', 'Only rows where the join condition matches in both tables', 'All rows from the left table and matching rows from the right', 'Only rows that appear in exactly one table']::text[], 1, 'INNER JOIN includes only rows with matching key values in both joined tables.', 'easy', 41),
  ('q-db-007', 'topic-databases', 'Which isolation problem occurs when a transaction reads uncommitted data from another transaction?', array['Lost update', 'Dirty read', 'Non-repeatable read', 'Phantom read']::text[], 1, 'A dirty read sees data that may be rolled back if the other transaction aborts.', 'medium', 42),
  ('q-db-008', 'topic-databases', 'How does a PRIMARY KEY differ from a UNIQUE constraint?', array['PRIMARY KEY allows NULL; UNIQUE does not', 'PRIMARY KEY uniquely identifies a row and a table typically has one; UNIQUE allows one NULL (in SQL) and a table may have several', 'UNIQUE is faster than PRIMARY KEY for all queries', 'PRIMARY KEY automatically creates a foreign key']::text[], 1, 'Both enforce uniqueness, but PRIMARY KEY is the main row identifier and implies NOT NULL.', 'medium', 43),
  ('q-db-009', 'topic-databases', 'What is the main goal of database normalization?', array['Increase redundant storage for speed', 'Reduce data redundancy and improve data integrity', 'Eliminate all indexes', 'Convert relational data to JSON documents']::text[], 1, 'Normalization organizes data to minimize duplication and update anomalies.', 'easy', 44),
  ('q-db-010', 'topic-databases', 'In ACID, what does Durability guarantee?', array['Transactions execute in isolation from each other', 'Committed changes survive system failures', 'All constraints are validated before commit', 'Transactions are indivisible']::text[], 1, 'Once a transaction commits, its effects persist even if the system crashes immediately after.', 'medium', 45),
  ('q-db-011', 'topic-databases', 'What is the best defense against SQL injection in application code?', array['Building queries by concatenating user input', 'Using parameterized queries / prepared statements', 'Storing passwords in plain text', 'Disabling all database indexes']::text[], 1, 'Parameterized queries separate SQL structure from user data, preventing injected commands from executing.', 'easy', 46),
  ('q-db-012', 'topic-databases', 'When is a NoSQL document store often a reasonable choice over a relational database?', array['When complex multi-table joins and strict ACID across entities are the primary need', 'When schema is flexible and data is naturally hierarchical or document-shaped', 'When every query requires strong relational normalization', 'When SQL is required by regulation in all cases']::text[], 1, 'Document stores fit evolving schemas and nested data; relational DBs excel at structured relationships and complex joins.', 'hard', 47),
  ('q-ds-013', 'topic-data-structures', 'What does a hash map store?', array['Only sorted values', 'Key–value pairs', 'Only unique integers', 'A fixed-size queue']::text[], 1, 'A hash map associates each key with a value and uses the key''s hash to find its bucket.', 'easy', 48),
  ('q-ds-014', 'topic-data-structures', 'In a binary tree, what is a *leaf* node?', array['The root node', 'A node with exactly one child', 'A node with no children', 'Any node at depth 1']::text[], 2, 'A leaf has no children. The root is the only node with no parent.', 'easy', 49),
  ('q-ds-015', 'topic-data-structures', 'Which operation adds an element to the top of a stack?', array['push', 'enqueue', 'poll', 'shift']::text[], 0, '`push` adds to the top of a stack and `pop` removes from the top. `enqueue` is the queue equivalent.', 'easy', 50),
  ('q-ds-016', 'topic-data-structures', 'What is the time complexity of building a binary heap from *n* unsorted elements with bottom-up heapify?', array['O(n log n)', 'O(log n)', 'O(n²)', 'O(n)']::text[], 3, 'Bottom-up heapify is O(n): most nodes sit near the bottom and sift down only a few levels, so the total work sums to a linear bound.', 'medium', 51),
  ('q-ds-017', 'topic-data-structures', 'Which structure gives O(1) average-time insert, delete, AND lookup by key?', array['Sorted array', 'Hash table', 'Singly linked list', 'Binary heap']::text[], 1, 'Hash tables give average O(1) for all three. A sorted array needs O(n) to insert, a linked list O(n) to look up, and a heap only finds the min/max fast.', 'medium', 52),
  ('q-ds-018', 'topic-data-structures', 'Why can an unbalanced binary search tree degrade to O(n) search?', array['Its keys are hashed', 'Inserting sorted keys can make it a linked-list-shaped chain', 'Every node stores the whole subtree', 'Search always visits both children']::text[], 1, 'Inserting keys in sorted order puts each new key on the same side, so the tree''s height becomes n. Self-balancing trees (AVL, red-black) keep the height O(log n).', 'hard', 53),
  ('q-ds-019', 'topic-data-structures', 'What is the amortized cost of `append` on a dynamic array that doubles its capacity when full?', array['O(1)', 'O(log n)', 'O(n)', 'O(n log n)']::text[], 0, 'An occasional resize copies n elements, but doubling means resizes are rare. Spread over all appends, the cost is O(1) each.', 'hard', 54),
  ('q-ds-020', 'topic-data-structures', 'A trie is especially efficient for which task?', array['Finding the median of a stream', 'Shortest paths in weighted graphs', 'Prefix lookups such as autocomplete', 'Range-sum queries on an array']::text[], 2, 'A trie shares common prefixes, so finding all keys with a prefix costs O(length of prefix) plus the size of the output.', 'hard', 55),
  ('q-ds-021', 'topic-data-structures', 'Which pair of structures is the classic way to build an LRU cache with O(1) get and put?', array['Two stacks', 'A min-heap and an array', 'A binary search tree and a queue', 'A hash map and a doubly linked list']::text[], 3, 'The hash map finds a node in O(1). The doubly linked list moves it to the front, or evicts the tail, in O(1).', 'hard', 56),
  ('q-ds-022', 'topic-data-structures', 'In a hash table using open addressing, what problem does a high load factor cause?', array['Keys lose their ordering', 'Long probe sequences, so slower operations', 'Collisions become impossible', 'The table must become a tree']::text[], 1, 'As the table fills, colliding keys form clusters and probes get longer. Tables resize when the load factor passes a threshold, often about 0.7.', 'hard', 57),
  ('q-algo-013', 'topic-algorithms', 'What is the worst-case time complexity of linear search?', array['O(1)', 'O(log n)', 'O(n)', 'O(n log n)']::text[], 2, 'Linear search may have to check every element before finding the target, or before concluding it''s absent.', 'easy', 58),
  ('q-algo-014', 'topic-algorithms', 'Which algorithm repeatedly swaps adjacent elements that are out of order?', array['Bubble sort', 'Merge sort', 'Binary search', 'Heap sort']::text[], 0, 'Bubble sort makes passes that swap adjacent out-of-order pairs, so the largest values ''bubble'' to the end.', 'easy', 59),
  ('q-algo-015', 'topic-algorithms', 'What does Big-O notation describe?', array['The exact running time in seconds', 'The amount of RAM installed', 'The number of lines of code', 'An upper bound on how cost grows with input size']::text[], 3, 'Big-O gives an asymptotic upper bound on growth. It ignores constants and hardware.', 'easy', 60),
  ('q-algo-016', 'topic-algorithms', 'Which traversal goes as deep as possible along a branch before backtracking?', array['Breadth-first search', 'Depth-first search', 'Level-order traversal', 'Dijkstra''s algorithm']::text[], 1, 'DFS follows one path to its end, then backtracks. It''s usually done with recursion or an explicit stack.', 'easy', 61),
  ('q-algo-017', 'topic-algorithms', 'What is *memoization*?', array['Sorting results before returning them', 'Storing the results of subproblems so they aren''t recomputed', 'Splitting input into halves', 'Running loops in parallel']::text[], 1, 'Memoization caches function results by input. It''s the top-down form of dynamic programming.', 'medium', 62),
  ('q-algo-018', 'topic-algorithms', 'Without memoization, what is the time complexity of naive recursive Fibonacci?', array['O(n)', 'O(n log n)', 'Exponential (about O(2ⁿ))', 'O(log n)']::text[], 2, 'Each call branches into two and recomputes the same subproblems, so the work grows exponentially. Memoization makes it O(n).', 'medium', 63),
  ('q-algo-019', 'topic-algorithms', 'Topological sort applies to which kind of graph?', array['Directed acyclic graphs', 'Any undirected graph', 'Graphs with negative cycles', 'Complete graphs only']::text[], 0, 'A topological order exists only if the directed graph has no cycles: each edge u→v needs u before v.', 'medium', 64),
  ('q-algo-020', 'topic-algorithms', 'Why can Dijkstra''s algorithm give wrong answers with negative edge weights?', array['It needs an adjacency matrix', 'It only works on trees', 'It runs in exponential time on them', 'It finalizes a vertex''s distance early, assuming paths only get longer']::text[], 3, 'Dijkstra greedily settles the closest unsettled vertex. A later negative edge could make a shorter path to it. Bellman-Ford handles negative weights.', 'hard', 65),
  ('q-algo-021', 'topic-algorithms', 'What is the lower bound for comparison-based sorting in the worst case?', array['Ω(n log n)', 'Ω(n)', 'Ω(log n)', 'Ω(n²)']::text[], 0, 'A comparison sort must tell apart n! orderings, and a decision tree with n! leaves has height Ω(log n!) = Ω(n log n).', 'hard', 66),
  ('q-algo-022', 'topic-algorithms', 'The 0/1 knapsack DP over n items with capacity W runs in O(nW). Why is that called *pseudo-polynomial*?', array['It uses randomness', 'W is a number, so the time is exponential in the bits needed to write W', 'It only works for small n', 'It needs O(2ⁿ) memory']::text[], 1, 'The running time is polynomial in W''s value but exponential in its bit length, which is the true input size.', 'hard', 67),
  ('q-os-013', 'topic-os-basics', 'What is the main job of an operating system?', array['Compile source code', 'Manage hardware resources and give programs services', 'Design user interfaces', 'Store web pages']::text[], 1, 'The OS manages the CPU, memory, storage, and devices, and gives programs abstractions like processes and files.', 'easy', 68),
  ('q-os-014', 'topic-os-basics', 'What is a *process*?', array['A program in execution, with its own address space', 'A file on disk', 'A CPU core', 'A network packet']::text[], 0, 'A process is a running instance of a program: code plus its own memory, registers, and OS resources.', 'easy', 69),
  ('q-os-015', 'topic-os-basics', 'Which memory is fastest for the CPU to access?', array['Main memory (RAM)', 'SSD', 'Hard disk', 'CPU registers']::text[], 3, 'Registers sit inside the CPU. Then come the caches (L1/L2/L3), then RAM, then storage.', 'easy', 70),
  ('q-os-016', 'topic-os-basics', 'What is the role of a *device driver*?', array['Schedule threads', 'Encrypt files', 'Let the OS talk to a specific piece of hardware', 'Compile kernel modules']::text[], 2, 'A driver translates generic OS requests into commands for one specific device.', 'easy', 71),
  ('q-os-017', 'topic-os-basics', 'What is a *race condition*?', array['Two threads compete for the fastest CPU', 'The result depends on the unpredictable timing of concurrent accesses to shared data', 'A deadlock between two processes', 'A process using too much memory']::text[], 1, 'If unsynchronized threads read and write shared state, the result depends on how they interleave. Locks or atomics prevent it.', 'medium', 72),
  ('q-os-018', 'topic-os-basics', 'What does a TLB (translation lookaside buffer) cache?', array['Disk blocks', 'Recent virtual-to-physical address translations', 'Open file descriptors', 'Network routes']::text[], 1, 'The TLB caches page-table entries, so most address translations skip walking the page table in memory.', 'medium', 73),
  ('q-os-019', 'topic-os-basics', 'What happens on a *page fault*?', array['The CPU halts permanently', 'The file system is corrupted', 'The OS loads the missing page from disk (or reports an invalid access)', 'The process is always terminated']::text[], 2, 'The hardware traps to the OS, which loads the page and resumes the process. If the address was invalid, it raises an error such as a segfault.', 'medium', 74),
  ('q-os-020', 'topic-os-basics', 'Always acquiring locks in one global order (*resource ordering*) prevents deadlock by breaking which Coffman condition?', array['Mutual exclusion', 'Hold and wait', 'No preemption', 'Circular wait']::text[], 3, 'If every thread takes locks in the same global order, a cycle of threads waiting on each other can''t form.', 'hard', 75),
  ('q-os-021', 'topic-os-basics', 'What is *priority inversion*?', array['A high-priority task waits on a lock held by a low-priority task that is itself preempted by medium-priority tasks', 'The scheduler reverses all priorities each tick', 'Low-priority tasks always run first', 'A task lowers its own priority to save power']::text[], 0, 'Medium-priority work keeps the lock holder off the CPU, so the high-priority task stalls. Priority inheritance is the usual fix.', 'hard', 76),
  ('q-os-022', 'topic-os-basics', 'Why does copy-on-write make `fork()` cheap?', array['It skips creating a new process', 'Parent and child share pages until one writes, and only then is that page copied', 'It copies memory to disk instead of RAM', 'It runs the child in kernel mode']::text[], 1, 'Pages start shared and read-only. A write triggers a fault that copies just that page, so pages that are never written are never copied.', 'hard', 77),
  ('q-db-013', 'topic-databases', 'Which SQL statement reads data from a table?', array['INSERT', 'UPDATE', 'SELECT', 'DELETE']::text[], 2, '`SELECT` queries rows. INSERT, UPDATE, and DELETE change data.', 'easy', 78),
  ('q-db-014', 'topic-databases', 'What does `NULL` mean in SQL?', array['Zero', 'An empty string', 'A missing or unknown value', 'False']::text[], 2, 'NULL marks an unknown or missing value. Compare with `IS NULL`, because `= NULL` is never true.', 'easy', 79),
  ('q-db-015', 'topic-databases', 'Which clause filters groups *after* aggregation?', array['WHERE', 'HAVING', 'ORDER BY', 'LIMIT']::text[], 1, 'WHERE filters rows before GROUP BY. HAVING filters the grouped results, e.g. `HAVING COUNT(*) > 5`.', 'medium', 80),
  ('q-db-016', 'topic-databases', 'What does a LEFT JOIN return?', array['All rows from the left table, plus matching right rows (NULLs where there''s no match)', 'Only matching rows from both tables', 'All rows from both tables', 'Only rows with no match']::text[], 0, 'A LEFT JOIN keeps every left row. Right-side columns are NULL where nothing matches.', 'medium', 81),
  ('q-db-017', 'topic-databases', 'What is a *composite* primary key?', array['A key made of two or more columns', 'A key that auto-increments', 'A key stored in another table', 'A key with a UNIQUE index only']::text[], 0, 'A composite key uses the combination of several columns to identify a row, e.g. (student_id, course_id).', 'medium', 82),
  ('q-db-018', 'topic-databases', 'Which isolation anomaly is a *non-repeatable read*?', array['Reading uncommitted data', 'Reading the same row twice in one transaction and getting different values', 'Two transactions both waiting on each other', 'Losing a committed write after a crash']::text[], 1, 'Another transaction committed an update between your two reads of the same row. REPEATABLE READ or higher prevents it.', 'medium', 83),
  ('q-db-019', 'topic-databases', 'Why might adding many indexes to a table slow down the application?', array['Indexes make SELECT slower', 'Indexes disable transactions', 'Every INSERT/UPDATE/DELETE must also update each index', 'Indexes delete old rows']::text[], 2, 'Indexes speed up reads, but each write has to maintain every index, which costs time and storage.', 'hard', 84),
  ('q-db-020', 'topic-databases', 'What is a *phantom read*?', array['A re-run range query returns new rows inserted by another committed transaction', 'Reading a row deleted by a crash', 'A query that never returns', 'Reading data from a backup']::text[], 0, 'The rows matching a predicate changed between your two runs of the same query. SERIALIZABLE isolation prevents it.', 'hard', 85),
  ('q-db-021', 'topic-databases', 'What does the CAP theorem say a distributed data store can''t guarantee all at once during a network partition?', array['Speed, size, and security', 'Atomicity, isolation, and durability', 'Caching, auditing, and paging', 'Consistency and availability together']::text[], 3, 'During a partition, a system must choose between consistency (every read sees the latest write) and availability (every request gets a response).', 'hard', 86),
  ('q-db-022', 'topic-databases', 'Why does a covering index speed up a query?', array['It caches the whole table in RAM', 'The index contains every column the query needs, so the base table isn''t read', 'It removes the need for a WHERE clause', 'It sorts results by primary key']::text[], 1, 'When all the needed columns are in the index, the database answers from the index alone and skips the extra lookups into the table.', 'hard', 87),
  ('q-oop-001', 'topic-oop', 'What is an object?', array['An instance of a class, with its own state', 'A function that returns a class', 'A file containing source code', 'A kind of loop']::text[], 0, 'A class is the blueprint; each object built from it holds its own values for the class''s fields.', 'easy', 88),
  ('q-oop-002', 'topic-oop', 'What is encapsulation?', array['Running code in parallel', 'Converting types automatically', 'Copying objects on assignment', 'Hiding internal state behind a public interface']::text[], 3, 'Callers use methods instead of poking at fields directly, so the object can keep itself valid.', 'easy', 89),
  ('q-oop-003', 'topic-oop', 'What does inheritance let a class do?', array['Hide all of its methods', 'Skip writing an initializer', 'Reuse and extend another class''s behavior', 'Run faster']::text[], 2, 'A subclass gets its superclass''s properties and methods, and can add or override them.', 'easy', 90),
  ('q-oop-004', 'topic-oop', 'What is a constructor (initializer) for?', array['Printing an object', 'Setting up a new object''s initial state', 'Deleting an object', 'Comparing two objects']::text[], 1, 'It runs when the object is created and gives every field a valid starting value.', 'easy', 91),
  ('q-oop-005', 'topic-oop', 'Inside a method, which keyword usually refers to the current object?', array['`self` / `this`', '`super`', '`static`', '`new`']::text[], 0, 'Swift and Python use `self`; Java and C++ use `this`.', 'easy', 92),
  ('q-oop-006', 'topic-oop', 'What is a method?', array['A variable shared by every program', 'A compiler setting', 'A database table', 'A function defined on a class or object']::text[], 3, 'Methods are the behavior attached to a type, and they can read and change the object''s state.', 'easy', 93),
  ('q-oop-007', 'topic-oop', 'If class `Dog` inherits from `Animal`, what is `Dog`?', array['An interface', 'A module', 'A subclass of Animal', 'Animal''s superclass']::text[], 2, 'Dog is the subclass (child); Animal is the superclass (parent).', 'easy', 94),
  ('q-oop-008', 'topic-oop', 'What does marking a member `private` mean?', array['It''s thread-safe', 'Only code inside its own type (or file, depending on the language) can use it', 'Anyone can change it', 'It''s saved to disk']::text[], 1, 'Access control is a tool for encapsulation: outside code can''t depend on private details.', 'easy', 95),
  ('q-oop-009', 'topic-oop', 'What is polymorphism?', array['The same call runs different code depending on the object''s actual type', 'Copying an object into several shapes', 'Having many initializers', 'Storing many objects in one array']::text[], 0, 'For example, `shape.area()` runs Circle''s or Square''s version depending on what `shape` holds.', 'medium', 96),
  ('q-oop-010', 'topic-oop', 'Overriding vs overloading?', array['They''re the same thing', 'Overloading happens at runtime; overriding never does', 'Overriding needs two unrelated classes', 'Overriding replaces a superclass method in a subclass; overloading defines same-named methods with different parameters']::text[], 3, 'Overrides are picked at runtime by the object''s type; overloads are picked at compile time by the arguments.', 'medium', 97),
  ('q-oop-011', 'topic-oop', 'What is an abstract class?', array['A class with only static members', 'A class defined inside a function', 'A class you can''t instantiate directly, which may leave methods for subclasses to implement', 'A class with no methods']::text[], 2, 'It captures shared structure while forcing subclasses to fill in the specifics.', 'medium', 98),
  ('q-oop-012', 'topic-oop', 'What does "composition over inheritance" suggest?', array['Share state through global variables', 'Build behavior by holding other objects instead of deep subclass trees', 'Never use classes', 'Always inherit from a base class']::text[], 1, 'A Car *has* an Engine rather than *being* one; parts can be swapped without changing a hierarchy.', 'medium', 99),
  ('q-oop-013', 'topic-oop', 'What is an interface (a protocol in Swift)?', array['A contract of methods and properties a type promises to provide', 'A screen in the user interface', 'A subclass with no parent', 'A compiled binary']::text[], 0, 'Different types can conform to the same interface and be used interchangeably.', 'medium', 100),
  ('q-oop-014', 'topic-oop', '`animal` is declared as `Animal` but holds a `Dog`. Which `speak()` runs (dynamic dispatch)?', array['Animal''s version, always', 'Neither; it''s a compile error', 'Both, one after the other', 'Dog''s override']::text[], 3, 'With dynamic dispatch the runtime type decides. (In C++ the method must be `virtual`.)', 'medium', 101),
  ('q-oop-015', 'topic-oop', 'What is a static (type-level) member?', array['A member only subclasses can see', 'A member stored in a database', 'One copy shared by the type, not one per instance', 'A member that can never change']::text[], 2, 'For example a counter of how many instances were created, or a factory method.', 'medium', 102),
  ('q-oop-016', 'topic-oop', 'What does the Single Responsibility Principle say?', array['Each class can have only one instance', 'A class should have one reason to change', 'A class should have only one method', 'A program should have only one class']::text[], 1, 'Mixing unrelated jobs in one class means unrelated changes keep touching (and breaking) it.', 'medium', 103),
  ('q-oop-017', 'topic-oop', 'What does the Liskov Substitution Principle require?', array['Subclasses must work anywhere the base class is expected without breaking correctness', 'Every class needs a default initializer', 'Prefer static methods to instance methods', 'Classes should be substituted with structs']::text[], 0, 'A subclass can''t strengthen preconditions or weaken the guarantees callers rely on.', 'hard', 104),
  ('q-oop-018', 'topic-oop', 'Why can a `Square` subclass of `Rectangle` violate Liskov substitution?', array['Squares have fewer methods', 'Squares can''t be drawn', 'Rectangle must be abstract', 'Code that sets width and height independently breaks the square''s equal-sides rule']::text[], 3, 'Code that is correct for any Rectangle (set width 2, height 5, expect area 10) fails for a Square.', 'hard', 105),
  ('q-oop-019', 'topic-oop', 'What is the "diamond problem"?', array['A sorting bug', 'An infinite loop between initializers', 'Ambiguity when a class inherits the same member from two parents that share an ancestor', 'A memory leak pattern']::text[], 2, 'Languages answer it differently: C++ virtual inheritance, Python''s MRO, or banning multiple class inheritance (Java, Swift).', 'hard', 106),
  ('q-oop-020', 'topic-oop', 'The Dependency Inversion Principle says high-level code should depend on…', array['The database schema', 'Abstractions (interfaces), not concrete low-level classes', 'Concrete low-level classes', 'Global singletons']::text[], 1, 'Then you can swap implementations (or test with fakes) without changing the high-level code.', 'hard', 107),
  ('q-oop-021', 'topic-oop', 'What is the "fragile base class" problem?', array['Changing a base class can unexpectedly break many subclasses', 'Base classes use too much memory', 'Base classes can''t have initializers', 'Subclasses can''t call super']::text[], 0, 'Subclasses often depend on base-class internals, so deep hierarchies make changes risky.', 'hard', 108),
  ('q-oop-022', 'topic-oop', 'The Open/Closed Principle says software should be…', array['Open source, not closed source', 'Open to callers, closed to subclasses', 'Opened once and closed after use', 'Open for extension, closed for modification']::text[], 3, 'Add behavior by adding new types (e.g. a new protocol conformance) instead of editing tested code.', 'hard', 109),
  ('q-net-001', 'topic-networking', 'What does DNS do?', array['Assigns MAC addresses', 'Compresses files', 'Translates domain names into IP addresses', 'Encrypts web traffic']::text[], 2, 'Your device asks a resolver for `example.com`''s address before it can connect.', 'easy', 110),
  ('q-net-002', 'topic-networking', 'Which protocol is the web built on?', array['SSH', 'HTTP', 'FTP', 'SMTP']::text[], 1, 'Browsers and APIs talk HTTP; HTTPS is HTTP over an encrypted TLS connection.', 'easy', 111),
  ('q-net-003', 'topic-networking', 'What does HTTPS add over HTTP?', array['Encryption and server authentication via TLS', 'Faster downloads', 'Bigger pages', 'Video support']::text[], 0, 'TLS keeps traffic private and proves (via a certificate) that you reached the real server.', 'easy', 112),
  ('q-net-004', 'topic-networking', 'What is an IP address?', array['A website''s name', 'A type of cable', 'A password', 'A numeric address that identifies a device on a network']::text[], 3, 'IPv4 addresses look like 192.0.2.10; IPv6 addresses are longer, like 2001:db8::1.', 'easy', 113),
  ('q-net-005', 'topic-networking', 'Which HTTP status code means "Not Found"?', array['301', '500', '404', '200']::text[], 2, '2xx = success, 3xx = redirect, 4xx = client error, 5xx = server error.', 'easy', 114),
  ('q-net-006', 'topic-networking', 'What is a port number for?', array['Storing cookies', 'Choosing which program on a host receives the traffic', 'Measuring bandwidth', 'Naming a Wi-Fi network']::text[], 1, 'The IP address picks the machine; the port picks the service (443 HTTPS, 22 SSH).', 'easy', 115),
  ('q-net-007', 'topic-networking', 'Which HTTP method is meant for reading data without side effects?', array['GET', 'POST', 'DELETE', 'PATCH']::text[], 0, 'GET should only retrieve; POST, PUT, PATCH, and DELETE change things.', 'easy', 116),
  ('q-net-008', 'topic-networking', 'What does a router do?', array['Stores web pages', 'Translates languages', 'Charges devices', 'Forwards packets between networks']::text[], 3, 'It reads each packet''s destination IP and sends it one hop closer.', 'easy', 117),
  ('q-net-009', 'topic-networking', 'What is the main difference between TCP and UDP?', array['TCP is only for video', 'They''re the same', 'TCP is connection-based with reliable, ordered delivery; UDP sends independent packets with no guarantees', 'UDP is always encrypted']::text[], 2, 'TCP retransmits and reorders for you; UDP is lighter and leaves that to the application.', 'medium', 118),
  ('q-net-010', 'topic-networking', 'What are the three steps of the TCP handshake?', array['DNS, ARP, DHCP', 'SYN, SYN-ACK, ACK', 'GET, POST, PUT', 'HELLO, AUTH, BYE']::text[], 1, 'Both sides agree on starting sequence numbers before any data flows.', 'medium', 119),
  ('q-net-011', 'topic-networking', 'In the TCP/IP model, which layer does IP belong to?', array['Internet (network) layer', 'Application layer', 'Transport layer', 'Link layer']::text[], 0, 'Link (Ethernet/Wi-Fi) → Internet (IP) → Transport (TCP/UDP) → Application (HTTP, DNS).', 'medium', 120),
  ('q-net-012', 'topic-networking', 'What does DHCP do?', array['Resolves domain names', 'Encrypts packets', 'Blocks malware', 'Hands out IP addresses and network settings to devices automatically']::text[], 3, 'When you join Wi-Fi, DHCP gives you an address, gateway, and DNS servers.', 'medium', 121),
  ('q-net-013', 'topic-networking', 'What does it mean that HTTP is stateless?', array['HTTP never fails', 'HTTP has no headers', 'Each request stands alone; the server doesn''t remember earlier ones by default', 'HTTP can''t send data']::text[], 2, 'Sessions are rebuilt on top with cookies or tokens sent on every request.', 'medium', 122),
  ('q-net-014', 'topic-networking', 'Why do video calls often use UDP?', array['Browsers require it', 'A late packet is useless, so waiting for retransmissions hurts more than a small loss', 'UDP is more reliable', 'UDP is encrypted by default']::text[], 1, 'Real-time media prefers fresh data over complete data.', 'medium', 123),
  ('q-net-015', 'topic-networking', 'What does NAT let a home network do?', array['Share one public IP address among many private devices', 'Speed up DNS', 'Encrypt Wi-Fi', 'Give every device its own public IP']::text[], 0, 'The router rewrites addresses and ports so replies reach the right device.', 'medium', 124),
  ('q-net-016', 'topic-networking', 'What is latency?', array['How much data moves per second', 'How many devices are connected', 'How big each packet is', 'How long data takes to get from source to destination']::text[], 3, 'Latency is delay; bandwidth is capacity. A fat pipe can still be slow to respond.', 'medium', 125),
  ('q-net-017', 'topic-networking', 'What does a TLS certificate prove?', array['The traffic is compressed', 'The server is fast', 'A trusted certificate authority vouches that the public key belongs to that domain', 'The site has no bugs']::text[], 2, 'Without it, an attacker in the middle could present their own key.', 'hard', 126),
  ('q-net-018', 'topic-networking', 'What is head-of-line blocking in HTTP/1.1 over TCP?', array['Cookies blocking requests', 'A slow or lost packet delays everything queued behind it on that connection', 'Too many headers in one request', 'A DNS cache failure']::text[], 1, 'HTTP/2 multiplexes streams but still shares one TCP byte stream; HTTP/3 fixes this with QUIC.', 'hard', 127),
  ('q-net-019', 'topic-networking', 'What does TCP congestion control do?', array['Adjusts the sending rate so the network isn''t overwhelmed', 'Encrypts packets', 'Chooses routes', 'Assigns port numbers']::text[], 0, 'It grows the send window while things go well and backs off when packets are lost.', 'hard', 128),
  ('q-net-020', 'topic-networking', 'Why is HTTP/3 built on QUIC over UDP?', array['Because UDP is reliable', 'To remove encryption', 'To support only IPv4', 'To avoid TCP head-of-line blocking and set up encrypted connections faster']::text[], 3, 'QUIC does reliability per stream in user space and merges the transport and TLS handshakes.', 'hard', 129),
  ('q-net-021', 'topic-networking', 'What does it mean that an HTTP method is idempotent?', array['It''s always cached', 'It returns no body', 'Sending the same request again has the same effect as sending it once', 'It never fails']::text[], 2, 'GET, PUT, and DELETE are idempotent; POST is not, so blind retries can duplicate work.', 'hard', 130),
  ('q-net-022', 'topic-networking', 'What does the bandwidth-delay product estimate?', array['The packet loss rate', 'How much data is in flight on a link (bandwidth × round-trip time)', 'The number of hops', 'DNS lookup time']::text[], 1, 'TCP''s window must be at least this big to keep a fast, long link busy.', 'hard', 131),
  ('q-swift-001', 'topic-swift', '`let` vs `var` in Swift?', array['`let` declares a constant; `var` declares a variable that can change', 'They''re the same', '`var` is only for strings', '`let` is only for functions']::text[], 0, 'Prefer `let`; the compiler warns when a `var` is never changed.', 'easy', 132),
  ('q-swift-002', 'topic-swift', 'What is `String?`?', array['A string that''s always empty', 'A deprecated type', 'A string that can''t contain characters', 'An optional: either a String or `nil`']::text[], 3, 'Optionals make "no value" explicit, so you must handle it before using the value.', 'easy', 133),
  ('q-swift-003', 'topic-swift', 'What does `if let name = maybeName { … }` do?', array['Declares a global', 'Loops over a string', 'Runs the body with the unwrapped value only if the optional isn''t nil', 'Crashes if the optional is nil']::text[], 2, 'Swift 5.7+ also allows the shorthand `if let maybeName { … }`.', 'easy', 134),
  ('q-swift-004', 'topic-swift', 'What does `??` do?', array['Creates an array', 'Supplies a default when an optional is nil', 'Compares two optionals by identity', 'Force-unwraps']::text[], 1, '`name ?? "Guest"` gives the name if present, otherwise "Guest".', 'easy', 135),
  ('q-swift-005', 'topic-swift', 'Which Swift collection stores key–value pairs?', array['Dictionary', 'Array', 'Set', 'Tuple']::text[], 0, '`[String: Int]` maps String keys to Int values.', 'easy', 136),
  ('q-swift-006', 'topic-swift', 'What is `"\(x)"` called?', array['A regular expression', 'Pattern matching', 'Optional chaining', 'String interpolation']::text[], 3, 'It inserts `x`''s description into the string.', 'easy', 137),
  ('q-swift-007', 'topic-swift', 'Which values does `for i in 0..<3` visit?', array['1, 2, 3', 'Only 3', '0, 1, 2', '0, 1, 2, 3']::text[], 2, '`..<` is a half-open range; `0...3` would include 3.', 'easy', 138),
  ('q-swift-008', 'topic-swift', 'How do you declare a Swift function that returns an Int?', array['`fn f() Int`', '`func f() -> Int`', '`function f(): Int`', '`def f() -> Int`']::text[], 1, '`->` introduces the return type.', 'easy', 139),
  ('q-swift-009', 'topic-swift', 'Struct vs class in Swift?', array['Structs are value types (copied); classes are reference types (shared)', 'Classes are copied; structs are shared', 'Structs can''t have methods', 'Classes can''t have properties']::text[], 0, 'Assigning a struct makes an independent copy; assigning a class makes another reference to the same object.', 'medium', 140),
  ('q-swift-010', 'topic-swift', 'Why must some struct methods be marked `mutating`?', array['They become async', 'They become static', 'They can be overridden', 'They change the struct''s own properties']::text[], 3, 'Struct methods can''t modify `self` unless marked `mutating`, and you can''t call them on a `let` constant.', 'medium', 141),
  ('q-swift-011', 'topic-swift', 'What is a closure?', array['A finished program', 'A closed file handle', 'A block of code that can capture values from the scope around it', 'A class that can''t be subclassed']::text[], 2, '`{ $0 * 2 }` passed to `map` is a closure.', 'medium', 142),
  ('q-swift-012', 'topic-swift', 'How does `guard let` differ from `if let`?', array['`guard let` ignores nil', 'The unwrapped value stays in scope after the guard, and the `else` must exit', 'There''s no difference', '`guard let` loops']::text[], 1, 'It keeps the happy path unindented: check early, exit early.', 'medium', 143),
  ('q-swift-013', 'topic-swift', 'What does `map` do on an array?', array['Returns a new array with each element transformed', 'Sorts the array', 'Removes duplicates', 'Finds the maximum']::text[], 0, '`[1, 2, 3].map { $0 * 10 }` gives `[10, 20, 30]`.', 'medium', 144),
  ('q-swift-014', 'topic-swift', 'What is a protocol in Swift?', array['Only a network protocol', 'A kind of subclass', 'A file format', 'A set of requirements that types can conform to']::text[], 3, 'Structs, classes, and enums can all conform, which enables protocol-oriented design.', 'medium', 145),
  ('q-swift-015', 'topic-swift', 'What happens when you force-unwrap (`x!`) a nil optional?', array['It returns an empty string', 'The line is skipped', 'The app crashes at runtime', 'It returns 0']::text[], 2, 'Use `if let`, `guard let`, or `??` unless nil really is impossible.', 'medium', 146),
  ('q-swift-016', 'topic-swift', 'What does `defer` do?', array['Skips a loop iteration', 'Runs its block when the current scope exits', 'Waits one second', 'Runs on a background thread']::text[], 1, 'Handy for cleanup that must happen on every exit path, including throws.', 'medium', 147),
  ('q-swift-017', 'topic-swift', 'What is a retain cycle?', array['Two objects hold strong references to each other, so ARC never frees either', 'An infinite loop', 'A recursive function', 'A kind of optional']::text[], 0, 'Common with closures stored on an object that capture `self` strongly.', 'hard', 148),
  ('q-swift-018', 'topic-swift', 'How does `[weak self]` in a closure help?', array['It makes the closure faster', 'It makes `self` permanently optional everywhere', 'It runs the closure on the main thread', 'The closure doesn''t keep `self` alive, which breaks retain cycles']::text[], 3, 'Inside the closure `self` becomes optional and is nil once the object is freed.', 'hard', 149),
  ('q-swift-019', 'topic-swift', 'What does copy-on-write mean for Swift arrays?', array['Arrays can''t be copied', 'Writes go to disk', 'Copies share storage until one is mutated; only then is the buffer copied', 'Every assignment copies immediately']::text[], 2, 'Value semantics without paying for a copy on every assignment.', 'hard', 150),
  ('q-swift-020', 'topic-swift', 'What does `@escaping` on a closure parameter mean?', array['The closure is optional', 'The closure may be called after the function returns', 'The closure can throw', 'The closure runs on another thread']::text[], 1, 'Completion handlers are escaping; `map`''s closure is not.', 'hard', 151),
  ('q-swift-021', 'topic-swift', 'What does a return type of `some View` (an opaque type) mean?', array['One specific concrete type conforming to View, hidden from callers', 'Any type at all, changing at runtime', 'An optional View', 'A protocol with no requirements']::text[], 0, 'The compiler knows the real type (fast, type-safe); callers only see "some View".', 'hard', 152),
  ('q-swift-022', 'topic-swift', 'What does actor isolation guarantee in Swift concurrency?', array['Code runs faster', 'Everything runs on the main thread', 'Classes become structs', 'Only one task at a time touches the actor''s mutable state']::text[], 3, 'Outside callers must `await`, and the compiler rejects unsynchronized access.', 'hard', 153),
  ('q-py-001', 'topic-python', 'What does `len([1, 2, 3])` return?', array['4', 'An error', '3', '2']::text[], 2, '`len` counts the items in a sequence or collection.', 'easy', 154),
  ('q-py-002', 'topic-python', 'Which of these types is immutable?', array['set', 'tuple', 'list', 'dict']::text[], 1, 'Tuples can''t be changed after creation, so they can be dict keys.', 'easy', 155),
  ('q-py-003', 'topic-python', 'How do you start a comment in Python?', array['`#`', '`//`', '`--`', '`/*`']::text[], 0, 'Everything after `#` on that line is ignored.', 'easy', 156),
  ('q-py-004', 'topic-python', 'Which values does `range(3)` produce?', array['1, 2, 3', '0, 1, 2, 3', 'Just 3', '0, 1, 2']::text[], 3, 'The stop value is excluded, just like slicing.', 'easy', 157),
  ('q-py-005', 'topic-python', 'What does a dict map?', array['Values to types', 'Files to folders', 'Keys to values', 'Indexes to keys']::text[], 2, '`{"ana": 31}` maps the key "ana" to the value 31.', 'easy', 158),
  ('q-py-006', 'topic-python', 'What does `def` do?', array['Imports a module', 'Defines a function', 'Deletes a variable', 'Defines a class']::text[], 1, '`def greet(name): ...` creates a function object called `greet`.', 'easy', 159),
  ('q-py-007', 'topic-python', 'What is `"a" * 3`?', array['`''aaa''`', 'An error', '`''a3''`', '`3`']::text[], 0, 'Multiplying a sequence by an int repeats it.', 'easy', 160),
  ('q-py-008', 'topic-python', 'What does `x in items` check?', array['The type of `x`', 'The length of `items`', 'Whether `x` and `items` are the same object', 'Whether `x` is one of the items']::text[], 3, 'Membership: O(n) for a list, O(1) on average for a set or dict.', 'easy', 161),
  ('q-py-009', 'topic-python', 'What is `[x * x for x in range(4) if x % 2 == 0]`?', array['`[4]`', '`[0, 2]`', '`[0, 4]`', '`[0, 1, 4, 9]`']::text[], 2, 'Only 0 and 2 pass the filter; squared they give 0 and 4.', 'medium', 162),
  ('q-py-010', 'topic-python', '`is` vs `==`?', array['`is` compares types', '`is` checks identity (same object); `==` checks equal values', 'They''re the same', '`==` checks identity']::text[], 1, 'Use `is` for `None` checks; use `==` for comparing values.', 'medium', 163),
  ('q-py-011', 'topic-python', 'What does `*args` collect in a function definition?', array['Extra positional arguments, as a tuple', 'Keyword arguments, as a dict', 'Only the first argument', 'Global variables']::text[], 0, '`**kwargs` is the keyword-argument counterpart (a dict).', 'medium', 164),
  ('q-py-012', 'topic-python', 'What does `items[-1]` return for a non-empty list?', array['The first element', 'An error', 'None', 'The last element']::text[], 3, 'Negative indexes count from the end.', 'medium', 165),
  ('q-py-013', 'topic-python', 'What does `with open(path) as f:` guarantee?', array['The file is created', 'The file is encrypted', 'The file is closed when the block exits, even after an error', 'The file is read-only']::text[], 2, '`with` uses the context-manager protocol (`__enter__` / `__exit__`).', 'medium', 166),
  ('q-py-014', 'topic-python', 'What is a generator (a function that uses `yield`)?', array['A compiler', 'A function that produces values lazily, one at a time', 'A function that runs in parallel', 'A way to create classes']::text[], 1, 'Generators keep their state between values and use little memory.', 'medium', 167),
  ('q-py-015', 'topic-python', 'What does `x = [1, 2]; y = x; y.append(3); print(x)` print?', array['`[1, 2, 3]`', '`[1, 2]`', '`[3]`', 'An error']::text[], 0, '`y = x` makes a second name for the same list, not a copy.', 'medium', 168),
  ('q-py-016', 'topic-python', 'What does `d.get(key, default)` do when the key is missing?', array['Raises KeyError', 'Inserts the key', 'Returns the first value', 'Returns `default` instead of raising KeyError']::text[], 3, '`d[key]` would raise; `.get` returns the default (None if you don''t give one).', 'medium', 169),
  ('q-py-017', 'topic-python', '`def f(items=[]): items.append(1); return items`. What does calling `f()` twice return the second time?', array['An error', '`[]`', '`[1, 1]`: the default list is created once and shared', '`[1]`']::text[], 2, 'Defaults are evaluated once, when `def` runs. Use `items=None` and create the list inside.', 'hard', 170),
  ('q-py-018', 'topic-python', 'What does CPython''s GIL mean for threads?', array['Threads can''t share memory', 'Only one thread runs Python bytecode at a time, so CPU-bound threads don''t run in parallel', 'Threads are not allowed', 'Threads run on the GPU']::text[], 1, 'Threads still help with I/O waits; use multiprocessing for CPU-bound parallelism.', 'hard', 171),
  ('q-py-019', 'topic-python', 'What does a decorator do?', array['Wraps a function to add behavior without changing its code', 'Formats strings', 'Declares types', 'Creates a class']::text[], 0, '`@cache` and `@property` are built-in examples.', 'hard', 172),
  ('q-py-020', 'topic-python', 'What is the average time complexity of `x in some_set`?', array['O(n)', 'O(log n)', 'O(n²)', 'O(1)']::text[], 3, 'Sets are hash tables; a list membership test is O(n).', 'hard', 173),
  ('q-py-021', 'topic-python', '`__new__` vs `__init__`?', array['`__init__` creates it; `__new__` deletes it', '`__new__` only works for strings', '`__new__` creates the instance; `__init__` initializes it', 'They''re the same']::text[], 2, 'You rarely need `__new__`, except for things like immutable types or singletons.', 'hard', 174),
  ('q-py-022', 'topic-python', 'What does `[f() for f in [lambda: i for i in range(3)]]` give?', array['An error', '`[2, 2, 2]`', '`[0, 1, 2]`', '`[0, 0, 0]`']::text[], 1, 'Each lambda looks up `i` when called, after the loop has finished at 2 (late binding).', 'hard', 175),
  ('q-ds-cc-01', 'topic-data-structures', 'Complete the code so `top` holds the last item pushed.

```python
stack = [1, 2, 3]
stack.append(4)
top = stack.___()
```', array['pop', 'remove', 'popleft', 'shift']::text[], 0, '`list.pop()` removes and returns the last item, which makes a list a stack. `popleft` belongs to `deque`, and `remove` needs a value to look for.', 'medium', 1000),
  ('q-ds-cc-02', 'topic-data-structures', 'Complete the code so it counts each letter.

```swift
var counts: [Character: Int] = [:]
for ch in "banana" {
    counts[ch, ___] += 1
}
```', array['default: 0', 'or: 0', 'initial: 0', '?? 0']::text[], 0, '`counts[ch, default: 0]` reads 0 for a missing key, so `+= 1` works the first time a letter is seen.', 'hard', 1001),
  ('q-alg-cc-01', 'topic-algorithms', 'Complete the midpoint of a binary search.

```python
while lo <= hi:
    mid = ___
```', array['(lo + hi) // 2', '(lo + hi) / 2', 'lo + hi // 2', 'hi - lo // 2']::text[], 0, '`//` is integer division, so `mid` is a valid index. `/` gives a float in Python 3, and without parentheses `//` only applies to `hi`.', 'medium', 1002),
  ('q-alg-cc-02', 'topic-algorithms', 'Complete the base case.

```python
def fib(n):
    if ___:
        return n
    return fib(n - 1) + fib(n - 2)
```', array['n < 2', 'n == 0', 'n > 1', 'n <= 2']::text[], 0, '`fib(0)` is 0 and `fib(1)` is 1, so both return `n`. With `n == 0`, `fib(1)` calls `fib(-1)` and never stops; with `n <= 2`, `fib(2)` wrongly returns 2.', 'hard', 1003),
  ('q-os-cc-01', 'topic-os-basics', 'Complete the code so only the child process prints.

```python
pid = os.fork()
if pid ___ 0:
    print("child")
```', array['==', '!=', '<', '>']::text[], 0, '`fork()` returns twice: 0 in the child, and the child''s process ID (a positive number) in the parent.', 'medium', 1004),
  ('q-os-cc-02', 'topic-os-basics', 'Both threads need the same two locks. Fill both blanks in thread B so the threads can''t deadlock.

```python
# thread A
with lock_a:
    with lock_b:
        transfer()

# thread B
with ___:
    with ___:
        transfer()
```', array['lock_a, then lock_b', 'lock_b, then lock_a', 'lock_b, then lock_b', 'Either order works']::text[], 0, 'Taking locks in the same order everywhere prevents deadlock. If B took `lock_b` first, A could hold `lock_a` while B holds `lock_b`, each waiting for the other forever.', 'hard', 1005),
  ('q-db-cc-01', 'topic-databases', 'Complete the query so it counts employees per department.

```sql
SELECT department, COUNT(*)
FROM employees
___ department;
```', array['GROUP BY', 'ORDER BY', 'WHERE', 'HAVING']::text[], 0, '`GROUP BY department` makes one row per department, and `COUNT(*)` counts the rows in each group.', 'medium', 1006),
  ('q-db-cc-02', 'topic-databases', 'Complete the query so it keeps only departments with more than 5 people.

```sql
SELECT department, COUNT(*)
FROM employees
GROUP BY department
___ COUNT(*) > 5;
```', array['HAVING', 'WHERE', 'AND', 'FILTER']::text[], 0, '`HAVING` filters groups after they''re counted. `WHERE` filters single rows before grouping, so it can''t use `COUNT(*)`.', 'hard', 1007),
  ('q-oop-cc-01', 'topic-oop', 'Complete the code so `Dog` still runs `Animal`''s setup.

```python
class Dog(Animal):
    def __init__(self, name):
        ___.__init__(name)
        self.tricks = []
```', array['super()', 'self', 'Animal()', 'base']::text[], 0, '`super()` reaches the parent class, so `Animal.__init__` sets up the name before `Dog` adds its own `tricks`.', 'medium', 1008),
  ('q-oop-cc-02', 'topic-oop', 'Complete the code so every `Greeter` gets `greet()` for free.

```swift
protocol Greeter {
    var name: String { get }
}

___ Greeter {
    func greet() -> String { "Hi, \(name)" }
}
```', array['extension', 'protocol', 'class', 'struct']::text[], 0, 'A protocol extension adds a default implementation. Every type that adopts `Greeter` gets `greet()` unless it writes its own.', 'hard', 1009),
  ('q-net-cc-01', 'topic-networking', 'Complete the code to open a UDP socket.

```python
sock = socket.socket(socket.AF_INET, socket.___)
```', array['SOCK_DGRAM', 'SOCK_STREAM', 'SOCK_RAW', 'SOCK_UDP']::text[], 0, '`SOCK_DGRAM` (datagram) is UDP. `SOCK_STREAM` is TCP, and there''s no `SOCK_UDP`.', 'medium', 1010),
  ('q-net-cc-02', 'topic-networking', 'Complete the code to download a URL''s data with async/await.

```swift
let (data, response) = try await URLSession.shared.___(from: url)
```', array['data', 'dataTask', 'download', 'fetch']::text[], 0, '`data(from:)` is async and returns `(Data, URLResponse)`. `dataTask` is the older completion-handler API, and `download(from:)` saves to a file and returns its URL.', 'hard', 1011),
  ('q-swift-cc-01', 'topic-swift', 'Complete the code so the function returns early when there''s no id.

```swift
func load(_ id: String?) {
    ___ let id else { return }
    print(id)
}
```', array['guard', 'if', 'while', 'defer']::text[], 0, '`guard let … else { return }` unwraps the optional and exits early when it''s nil. After it, `id` is a plain `String` for the rest of the function.', 'medium', 1012),
  ('q-swift-cc-02', 'topic-swift', 'Complete the code so it keeps only the strings that are numbers.

```swift
let numbers = ["1", "x", "3"].___ { Int($0) }
// [1, 3]
```', array['compactMap', 'map', 'flatMap', 'filter']::text[], 0, '`compactMap` transforms each item and drops the nils. `map` would give `[1, nil, 3]`, `filter` needs a Bool, and `flatMap` for optionals is the old, deprecated name.', 'hard', 1013),
  ('q-py-cc-01', 'topic-python', 'Complete the code so it prints each name with its position.

```python
for i, name in ___(names):
    print(i, name)
```', array['enumerate', 'range', 'zip', 'len']::text[], 0, '`enumerate` yields `(index, item)` pairs, so you get the position without keeping a counter.', 'medium', 1014),
  ('q-py-cc-02', 'topic-python', 'Complete the code to build this dictionary.

```python
squares = ___
# {1: 1, 2: 4, 3: 9}
```', array['{n: n * n for n in range(1, 4)}', '[n: n * n for n in range(1, 4)]', '{n * n for n in range(1, 4)}', 'dict(n, n * n for n in range(1, 4))']::text[], 0, 'A dict comprehension uses braces with `key: value`. Without the colon it''s a set comprehension; square brackets with a colon is a syntax error.', 'hard', 1015)
on conflict (id) do update set topic_id = excluded.topic_id, prompt = excluded.prompt, options = excluded.options, correct_option_index = excluded.correct_option_index, explanation = excluded.explanation, difficulty = excluded.difficulty, sort_index = excluded.sort_index;

-- content_exercises: 25 rows
insert into public.content_exercises (id, topic_id, title, language, prompt, code, blanks, explanation, sort_index) values
  ('ex-swift-if-let', 'topic-swift', 'Unwrap an optional', 'swift', 'Greet the user by name when there is one.', 'func greet(_ name: String?) -> String {
    ___ let name {
        return "Hello, \(name)!"
    }
    return "Hello, stranger!"
}', '[{"accepted": ["if"]}]'::jsonb, '`if let name` unwraps the optional: the block runs only when `name` is not nil, and inside it `name` is a plain `String`.', 0),
  ('ex-swift-guard', 'topic-swift', 'Exit early with guard', 'swift', 'Return nil instead of dividing by zero.', 'func divide(_ a: Int, by b: Int) -> Int? {
    ___ b != 0 ___ {
        return nil
    }
    return a / b
}', '[{"accepted": ["guard"]}, {"accepted": ["else"]}]'::jsonb, '`guard condition else { ... }` runs the `else` block when the condition is false, and that block must leave the scope (here with `return nil`).', 1),
  ('ex-swift-map', 'topic-swift', 'Transform an array', 'swift', 'Square every number in the array.', 'let numbers = [1, 2, 3, 4]
let squares = numbers.___ { $0 * $0 }
// squares == [1, 4, 9, 16]', '[{"accepted": ["map"]}]'::jsonb, '`map` calls the closure on every element and returns a new array of the results, in the same order.', 2),
  ('ex-swift-mutating', 'topic-swift', 'Change a struct from a method', 'swift', 'Let `increment()` change the counter''s stored property.', 'struct Counter {
    var count = 0

    ___ func increment() {
        count += 1
    }
}', '[{"accepted": ["mutating"]}]'::jsonb, 'Structs are value types, so a method that changes a stored property must be marked `mutating`.', 3),
  ('ex-python-def', 'topic-python', 'Define a function', 'python', 'Define a function that returns the area of a rectangle.', '___ area(width, height):
    return width * height', '[{"accepted": ["def"]}]'::jsonb, 'Python functions start with `def`, then the name, the parameters in parentheses, and a colon.', 4),
  ('ex-python-comprehension', 'topic-python', 'Filter with a list comprehension', 'python', 'Keep only the even numbers.', 'numbers = [1, 2, 3, 4, 5, 6]
evens = [n ___ n in numbers ___ n % 2 == 0]
# evens == [2, 4, 6]', '[{"accepted": ["for"]}, {"accepted": ["if"]}]'::jsonb, 'A list comprehension reads `[expression for item in iterable if condition]`; the `if` part drops items that fail the test.', 5),
  ('ex-python-dict-get', 'topic-python', 'Count words with a dictionary', 'python', 'Count each word, starting from 0 for words not seen yet.', 'counts = {}
for word in ["a", "b", "a"]:
    counts[word] = counts.___(word, 0) + 1
# counts == {"a": 2, "b": 1}', '[{"accepted": ["get"]}]'::jsonb, '`dict.get(key, default)` returns the default instead of raising `KeyError` when the key is missing.', 6),
  ('ex-alg-binary-search', 'topic-algorithms', 'Binary search', 'python', 'Finish the loop condition and move the lower bound.', 'def binary_search(items, target):
    low, high = 0, len(items) - 1
    while low ___ high:
        mid = (low + high) // 2
        if items[mid] == target:
            return mid
        elif items[mid] < target:
            low = ___
        else:
            high = mid - 1
    return -1', '[{"accepted": ["<="]}, {"accepted": ["mid + 1", "1 + mid"]}]'::jsonb, 'The range is inclusive, so the loop runs while `low <= high`. When the middle item is too small, the target can only be to its right, so `low = mid + 1`.', 7),
  ('ex-alg-factorial', 'topic-algorithms', 'Recursive factorial', 'swift', 'Give the base case and the recursive call.', 'func factorial(_ n: Int) -> Int {
    if n <= 1 { return ___ }
    return n * factorial(___)
}', '[{"accepted": ["1"]}, {"accepted": ["n - 1"]}]'::jsonb, '0! and 1! are both 1, which stops the recursion. Every other call multiplies `n` by the factorial of the next smaller number, `n - 1`.', 8),
  ('ex-ds-stack', 'topic-data-structures', 'Build a stack', 'swift', 'Push onto and pop from the end of the array.', 'struct Stack<Element> {
    private var items: [Element] = []

    mutating func push(_ item: Element) {
        items.___(item)
    }

    mutating func pop() -> Element? {
        items.___()
    }
}', '[{"accepted": ["append"]}, {"accepted": ["popLast"]}]'::jsonb, 'A stack is last in, first out. `append` adds to the end, and `popLast()` removes from the end, returning nil when the stack is empty (unlike `removeLast()`, which crashes).', 9),
  ('ex-ds-queue', 'topic-data-structures', 'Use a queue', 'python', 'Take the oldest item out of the queue.', 'from collections import deque

queue = deque()
queue.append("a")
queue.append("b")
first = queue.___()
# first == "a"  (first in, first out)', '[{"accepted": ["popleft"]}]'::jsonb, 'A queue is first in, first out. `deque.popleft()` removes from the front in O(1); `list.pop(0)` would be O(n).', 10),
  ('ex-oop-inheritance', 'topic-oop', 'Inherit from a class', 'java', 'Make `Dog` a subclass of `Animal`.', 'class Animal {
    String sound() { return "..."; }
}

class Dog ___ Animal {
    @Override
    String sound() { return "Woof"; }
}', '[{"accepted": ["extends"]}]'::jsonb, 'In Java a class inherits with `extends`. `@Override` asks the compiler to check that `sound()` really replaces a method of the superclass.', 11),
  ('ex-db-where', 'topic-databases', 'Filter rows', 'python', 'List the products that cost less than 20.', 'import sqlite3

db = sqlite3.connect("shop.db")
rows = db.execute(
    "SELECT name, price FROM products ___ price < ?",
    (20,),
).fetchall()', '[{"accepted": ["WHERE", "where"]}]'::jsonb, '`WHERE` keeps only the rows whose condition is true. The `?` is filled in with 20 by the database, not by string formatting.', 100),
  ('ex-db-order-limit', 'topic-databases', 'Top three scores', 'python', 'Get the three highest scores, best first.', 'top = db.execute(
    "SELECT name, score FROM players ___ score DESC ___ 3"
).fetchall()', '[{"accepted": ["ORDER BY", "order by"]}, {"accepted": ["LIMIT", "limit"]}]'::jsonb, '`ORDER BY score DESC` sorts from highest to lowest, then `LIMIT 3` keeps only the first three rows.', 101),
  ('ex-db-placeholder', 'topic-databases', 'Query safely', 'python', 'Look up a user by email without building SQL from the input.', 'def find_user(db, email):
    return db.execute(
        "SELECT id FROM users WHERE email = ___",
        (email,),
    ).fetchone()', '[{"accepted": ["?"]}]'::jsonb, '`?` is a placeholder: sqlite3 sends the email separately from the SQL, so input like `'' OR 1=1 --` can''t change the query (no SQL injection).', 102),
  ('ex-db-group-by', 'topic-databases', 'Count per customer', 'python', 'Count how many orders each customer placed.', 'counts = db.execute(
    "SELECT customer_id, COUNT(*) FROM orders ___ customer_id"
).fetchall()', '[{"accepted": ["GROUP BY", "group by"]}]'::jsonb, '`GROUP BY customer_id` makes one row per customer, and `COUNT(*)` counts the orders in each group.', 103),
  ('ex-net-tcp-socket', 'topic-networking', 'Open a TCP connection', 'python', 'Connect to a web server over TCP.', 'import socket

sock = socket.socket(socket.AF_INET, socket.___)
sock.connect(("example.com", 80))', '[{"accepted": ["SOCK_STREAM"]}]'::jsonb, '`SOCK_STREAM` is TCP: a reliable, ordered byte stream. `SOCK_DGRAM` would be UDP, which sends separate packets with no delivery guarantee.', 104),
  ('ex-net-http-status', 'topic-networking', 'Read the status', 'python', 'Fetch a page and keep its HTTP status code.', 'import urllib.request

with urllib.request.urlopen("https://example.com") as response:
    status = response.___
    body = response.read().decode("utf-8")', '[{"accepted": ["status", "getcode()", "code"]}]'::jsonb, 'The response''s `status` is the HTTP status code, such as 200. `read()` returns the body as bytes, so it''s decoded to text.', 105),
  ('ex-net-success-range', 'topic-networking', 'Is it a success?', 'swift', 'Return true for any 2xx status code.', 'func isSuccess(_ status: Int) -> Bool {
    (___).contains(status)
}', '[{"accepted": ["200..<300", "200...299"]}]'::jsonb, 'Every 2xx code means success. `200..<300` is a half-open range: it includes 200 and stops before 300.', 106),
  ('ex-os-thread-join', 'topic-os-basics', 'Start and wait', 'python', 'Run `work` on a thread, and wait for it before printing done.', 'import threading

def work():
    print("working")

t = threading.Thread(target=work)
t.___()
t.___()
print("done")', '[{"accepted": ["start"]}, {"accepted": ["join"]}]'::jsonb, '`start()` runs the function on a new thread. `join()` blocks until that thread finishes, so `done` always prints last.', 107),
  ('ex-os-lock', 'topic-os-basics', 'Guard shared state', 'python', 'Make the increment safe when many threads call it.', 'import threading

count = 0
lock = threading.Lock()

def increment():
    global count
    ___ lock:
        count += 1', '[{"accepted": ["with"]}]'::jsonb, '`with lock:` acquires the lock, runs the block, and releases it even if something fails. Only one thread at a time can change `count`.', 108),
  ('ex-os-async-let', 'topic-os-basics', 'Load in parallel', 'swift', 'Fetch the user and their posts at the same time, then return both.', 'func loadAll() async throws -> (User, [Post]) {
    async let user = fetchUser()
    async let posts = fetchPosts()
    return try ___ (user, posts)
}', '[{"accepted": ["await"]}]'::jsonb, '`async let` starts both calls right away. `await` waits for both results; `try` passes on an error from either.', 109),
  ('ex-oop-protocol', 'topic-oop', 'Adopt a protocol', 'swift', 'Make `Square` a `Shape`.', 'protocol Shape {
    func area() -> Double
}

struct Square: ___ {
    let side: Double
    func area() -> Double { side * side }
}', '[{"accepted": ["Shape"]}]'::jsonb, 'Listing `Shape` after the colon adopts the protocol. Square then has to provide `area()`, and can be used anywhere a `Shape` is expected.', 110),
  ('ex-oop-override', 'topic-oop', 'Override a method', 'java', 'Give `Dog` its own sound.', 'class Animal {
    String sound() { return "..."; }
}

class Dog extends Animal {
    ___
    String sound() { return "Woof"; }
}', '[{"accepted": ["@Override"]}]'::jsonb, '`@Override` tells the compiler this method replaces one from `Animal`. If the name or parameters don''t match, it''s a compile error instead of a silent new method.', 111),
  ('ex-oop-init', 'topic-oop', 'Write an initializer', 'python', 'Give every account an owner and a zero balance.', 'class Account:
    def ___(self, owner):
        self.owner = owner
        self.balance = 0', '[{"accepted": ["__init__"]}]'::jsonb, '`__init__` runs when you call `Account("Ada")`. `self` is the new object, so `self.owner` and `self.balance` become its attributes.', 112)
on conflict (id) do update set topic_id = excluded.topic_id, title = excluded.title, language = excluded.language, prompt = excluded.prompt, code = excluded.code, blanks = excluded.blanks, explanation = excluded.explanation, sort_index = excluded.sort_index;

-- content_decks: 15 rows
insert into public.content_decks (starter_key, topic_id, title, sort_index) values
  ('starter-ds', 'topic-data-structures', 'Data Structures Essentials', 0),
  ('starter-algo', 'topic-algorithms', 'Algorithms Essentials', 1),
  ('starter-os', 'topic-os-basics', 'OS Basics Essentials', 2),
  ('starter-db', 'topic-databases', 'Databases Essentials', 3),
  ('starter-ds-2', 'topic-data-structures', 'Trees & Graphs', 4),
  ('starter-algo-2', 'topic-algorithms', 'Sorting & Searching', 5),
  ('starter-os-2', 'topic-os-basics', 'Concurrency', 6),
  ('starter-db-2', 'topic-databases', 'SQL Queries', 7),
  ('starter-oop', 'topic-oop', 'OOP Essentials', 8),
  ('starter-net', 'topic-networking', 'Networking Essentials', 9),
  ('starter-swift', 'topic-swift', 'Swift Essentials', 10),
  ('starter-python', 'topic-python', 'Python Essentials', 11),
  ('starter-net-2', 'topic-networking', 'HTTP & the Web', 100),
  ('starter-oop-2', 'topic-oop', 'Design Patterns', 101),
  ('starter-python-2', 'topic-python', 'Python Idioms', 102)
on conflict (starter_key) do update set topic_id = excluded.topic_id, title = excluded.title, sort_index = excluded.sort_index;

-- content_cards: 174 rows
insert into public.content_cards (id, deck_key, prompt, answer, difficulty, code_language, code_source, sort_index) values
  ('sc-algo-001', 'starter-algo', 'What precondition does **binary search** need?', 'The input must be **sorted**. Each step compares the target with the middle element and discards half of the range.', 'easy', null, null, 0),
  ('sc-algo2-001', 'starter-algo-2', 'Why does binary search need a sorted array?', 'Comparing with the middle element tells you which **half** can''t contain the target. That only works when the order is known.', 'easy', null, null, 0),
  ('sc-db-001', 'starter-db', 'What is a **primary key**?', 'A column, or set of columns, that uniquely identifies each row. It can''t be `NULL` and can''t repeat.', 'easy', null, null, 0),
  ('sc-db2-001', 'starter-db-2', 'What does `SELECT DISTINCT city FROM users` return?', 'Each city **once**, however many users live there.', 'easy', null, null, 0),
  ('sc-ds-001', 'starter-ds', 'What is the time complexity of reading `arr[i]` from an array?', '**O(1)**. The element''s address is computed directly from the array''s base address and the index, so no searching is needed.', 'easy', null, null, 0),
  ('sc-ds2-001', 'starter-ds-2', 'What is a binary tree?', 'A tree where every node has **at most two children**, usually called left and right.', 'easy', null, null, 0),
  ('sc-net-001', 'starter-net', 'What does DNS do?', 'Translates a **name** like `example.com` into an **IP address** the network can route to. Answers are cached at several levels so lookups stay fast.', 'easy', null, null, 0),
  ('sc-net2-001', 'starter-net-2', 'What does an HTTP **GET** request do?', 'Asks the server for a resource. It shouldn''t change anything on the server, so it''s safe to repeat and can be cached.', 'easy', null, null, 0),
  ('sc-oop-001', 'starter-oop', 'Class vs object?', 'A **class** is the blueprint (fields and methods). An **object** is one instance built from it, with its own state.', 'easy', null, null, 0),
  ('sc-oop2-001', 'starter-oop-2', 'What is the **Singleton** pattern?', 'A class with exactly one shared instance, reached through a static property (`static let shared` in Swift). Useful, but it''s global state, so use it sparingly.', 'easy', null, null, 0),
  ('sc-os-001', 'starter-os', 'What''s the difference between a **process** and a **thread**?', 'A process has its own address space. Threads run *inside* a process and share its memory.', 'easy', null, null, 0),
  ('sc-os2-001', 'starter-os-2', 'What is a thread?', 'An independent path of execution **inside a process**. Threads in one process share memory, so they can cooperate quickly but must coordinate access.', 'easy', null, null, 0),
  ('sc-py-001', 'starter-python', 'What does this print?', '`[''b'', ''c''] [''d'', ''e''] [''a'', ''c'', ''e'']`. Slices are `[start:stop:step]`: `stop` is excluded, and negative indexes count from the end.', 'easy', 'python', 'letters = ["a", "b", "c", "d", "e"]
print(letters[1:3], letters[-2:], letters[::2])', 0),
  ('sc-py2-001', 'starter-python-2', 'What does `enumerate(items)` give you?', '`(index, item)` pairs, so you can write `for i, item in enumerate(items)` instead of keeping a counter.', 'easy', null, null, 0),
  ('sc-swift-001', 'starter-swift', 'What does this print?', '`Hi, Guest!`. `??` (nil-coalescing) unwraps the optional, or uses the default when it''s nil.', 'easy', 'swift', 'let input: String? = nil
let name = input ?? "Guest"
print("Hi, \(name)!")', 0),
  ('sc-algo-002', 'starter-algo', 'What is the time complexity of binary search?', '**O(log n)**, because the search range halves at every step.', 'easy', null, null, 1),
  ('sc-algo2-002', 'starter-algo-2', 'What does selection sort do on each pass?', 'Finds the **smallest** remaining element and swaps it into the next position. It always makes O(n²) comparisons, even on sorted input.', 'easy', null, null, 1),
  ('sc-db-002', 'starter-db', 'What is a **foreign key**?', 'A column that references another table''s primary key. It enforces that the referenced row exists (referential integrity).', 'easy', null, null, 1),
  ('sc-db2-002', 'starter-db-2', 'What does `ORDER BY score DESC` do?', 'Sorts rows by `score` from **highest to lowest**. `ASC`, the default, sorts lowest first.', 'easy', null, null, 1),
  ('sc-ds-002', 'starter-ds', 'In what order does a **stack** remove elements?', '**LIFO** (last in, first out). `push` adds to the top and `pop` removes from the top.', 'easy', null, null, 1),
  ('sc-ds2-002', 'starter-ds-2', 'What makes a binary *search* tree special?', 'For every node, keys in the **left** subtree are smaller and keys in the **right** subtree are larger. That ordering lets a search skip half the tree at each step when the tree is balanced.', 'easy', null, null, 1),
  ('sc-net-002', 'starter-net', 'IP address vs port?', 'The **IP address** picks the machine; the **port** picks the program on it (443 for HTTPS, 22 for SSH).', 'easy', null, null, 1),
  ('sc-net2-002', 'starter-net-2', 'What does status **404** mean?', '**Not Found**: the server answered, but nothing exists at that path.', 'easy', null, null, 1),
  ('sc-oop-002', 'starter-oop', 'What is encapsulation?', 'Keeping an object''s data **private** and exposing behavior through methods, so callers can''t put the object into an invalid state.', 'easy', null, null, 1),
  ('sc-oop2-002', 'starter-oop-2', 'What is the **Observer** pattern?', 'Objects subscribe to another object and are told when it changes. Notifications, Combine and SwiftUI''s `@Observable` all work this way.', 'easy', null, null, 1),
  ('sc-os-002', 'starter-os', 'What is a **context switch**?', 'The OS saves the running task''s state (registers, program counter) and restores another task''s state, so the CPU can switch between them.', 'easy', null, null, 1),
  ('sc-os2-002', 'starter-os-2', 'What does a mutex (lock) do?', 'It lets **only one thread at a time** into a critical section. Other threads wait until the holder unlocks.', 'easy', null, null, 1),
  ('sc-py-002', 'starter-python', 'List vs tuple?', 'Both are ordered sequences. A **list** is mutable (append, change items); a **tuple** is immutable, so it can be a dict key.', 'easy', null, null, 1),
  ('sc-py2-002', 'starter-python-2', 'What does `zip(a, b)` do?', 'Pairs items by position: `zip([1, 2], [''a'', ''b''])` gives `(1, ''a'')` and `(2, ''b'')`. It stops at the shorter one.', 'easy', null, null, 1),
  ('sc-swift-002', 'starter-swift', '`let` or `var`?', '`let` declares a **constant** that can''t be reassigned; `var` declares a **variable**. Prefer `let` unless the value really changes.', 'easy', null, null, 1),
  ('sc-algo-003', 'starter-algo', 'What does this print, and what is the base case?', '`24`. The base case is `n == 0`, which returns `1`. Without it, the recursion would never stop.', 'easy', 'python', 'def factorial(n):
    if n == 0:
        return 1
    return n * factorial(n - 1)

print(factorial(4))', 2),
  ('sc-algo2-003', 'starter-algo-2', 'When does insertion sort run in O(n)?', 'On an **already sorted** array: each new element is compared once and stays where it is.', 'easy', null, null, 2),
  ('sc-db-003', 'starter-db', 'What does this print?', '`1`. One row was inserted. `fetchone()` returns the tuple `(1,)`, and `[0]` takes the count from it.', 'easy', 'python', 'import sqlite3

db = sqlite3.connect(":memory:")
db.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")
db.execute("INSERT INTO users (name) VALUES (?)", ("Ada",))
print(db.execute("SELECT COUNT(*) FROM users").fetchone()[0])', 2),
  ('sc-db2-003', 'starter-db-2', '`COUNT(*)` vs `COUNT(email)`?', '`COUNT(*)` counts **rows**. `COUNT(email)` counts only rows where `email` is **not NULL**.', 'easy', null, null, 2),
  ('sc-ds-003', 'starter-ds', 'In what order does a **queue** remove elements?', '**FIFO** (first in, first out). You enqueue at the back and dequeue from the front.', 'easy', null, null, 2),
  ('sc-ds2-003', 'starter-ds-2', 'What is a graph?', 'A set of **vertices** (nodes) connected by **edges**. Edges can be directed or undirected, weighted or unweighted.', 'easy', null, null, 2),
  ('sc-net-003', 'starter-net', 'What do the HTTP status classes mean?', '**2xx** success, **3xx** redirect, **4xx** client error (like 404), **5xx** server error (like 500).', 'easy', null, null, 2),
  ('sc-net2-003', 'starter-net-2', 'What''s the difference between **4xx** and **5xx** status codes?', '**4xx**: the request was wrong (bad input, not signed in, missing page). **5xx**: the server failed while handling a valid request.', 'easy', null, null, 2),
  ('sc-oop-003', 'starter-oop', 'What does this print?', '`3`. Each `tap()` changes this object''s own `count`, and returning `self` lets the calls chain.', 'easy', 'python', 'class Counter:
    def __init__(self):
        self.count = 0

    def tap(self):
        self.count += 1
        return self

c = Counter()
c.tap().tap().tap()
print(c.count)', 2),
  ('sc-oop2-003', 'starter-oop-2', 'What is the **Factory** pattern?', 'One place creates objects, so callers ask for what they need instead of calling a specific initializer. Changing what gets built only changes the factory.', 'easy', null, null, 2),
  ('sc-os-003', 'starter-os', 'What is **virtual memory**?', 'Each process sees its own private address space. The OS and the MMU map those virtual pages to physical frames, or to disk.', 'easy', null, null, 2),
  ('sc-os2-003', 'starter-os-2', 'What is a critical section?', 'Code that touches **shared data** and must not run in more than one thread at once.', 'easy', null, null, 2),
  ('sc-py-003', 'starter-python', 'What does this print?', '`[''apples'', ''kiwis'']`. `.items()` yields key–value pairs, and the comprehension keeps names with a positive quantity. Dicts keep insertion order.', 'easy', 'python', 'stock = {"apples": 3, "pears": 0, "kiwis": 5}
in_stock = [name for name, qty in stock.items() if qty > 0]
print(in_stock)', 2),
  ('sc-py2-003', 'starter-python-2', 'How do you swap two variables in Python?', '`a, b = b, a`. The right side is built into a tuple first, then unpacked.', 'easy', null, null, 2),
  ('sc-swift-003', 'starter-swift', 'What does this print?', '`18`. `1...10` is a closed range, and `where` keeps only the multiples of 3: 3 + 6 + 9.', 'easy', 'swift', 'var total = 0
for n in 1...10 where n % 3 == 0 {
    total += n
}
print(total)', 2),
  ('sc-algo-004', 'starter-algo', 'What makes a sort **stable**?', 'It keeps equal elements in their original relative order. Merge sort is stable; a typical in-place quicksort is not.', 'easy', null, null, 3),
  ('sc-algo2-004', 'starter-algo-2', 'What does this print?', '`(5, 2)`. Step 1 checks index 3 (value 7) and moves right; step 2 checks index 5 and finds 11. Each step halves the range, so binary search is **O(log n)**.', 'easy', 'python', 'def binary_search(items, target):
    lo, hi, steps = 0, len(items) - 1, 0
    while lo <= hi:
        steps += 1
        mid = (lo + hi) // 2
        if items[mid] == target:
            return mid, steps
        if items[mid] < target:
            lo = mid + 1
        else:
            hi = mid - 1
    return -1, steps

print(binary_search([1, 3, 5, 7, 9, 11, 13], 11))', 3),
  ('sc-db-004', 'starter-db', 'What does **ACID** stand for?', '**Atomicity, Consistency, Isolation, Durability**: the guarantees a database transaction gives.', 'easy', null, null, 3),
  ('sc-db2-004', 'starter-db-2', 'What does this print?', '`[(''Cy'',), (''Ana'',)]`. `WHERE` keeps people older than 20 (Ana, Cy), and `ORDER BY age` sorts them youngest first. The `?` placeholders are also how you prevent SQL injection.', 'easy', 'python', 'import sqlite3

db = sqlite3.connect(":memory:")
db.execute("CREATE TABLE users (name TEXT, age INTEGER)")
db.executemany("INSERT INTO users VALUES (?, ?)", [("Ana", 31), ("Bo", 19), ("Cy", 25)])
rows = db.execute("SELECT name FROM users WHERE age > 20 ORDER BY age").fetchall()
print(rows)', 3),
  ('sc-ds-004', 'starter-ds', 'What does this print?', '`4 3`. `removeLast()` pops the element that was just appended, leaving three items.', 'easy', 'swift', 'var stack = [1, 2, 3]
stack.append(4)
let top = stack.removeLast()
print(top, stack.count)', 3),
  ('sc-ds2-004', 'starter-ds-2', 'What does this print?', '`[1, 3, 5, 8, 9]`. An **in-order** traversal (left, node, right) of a binary search tree visits the keys in sorted order.', 'easy', 'python', 'class Node:
    def __init__(self, key, left=None, right=None):
        self.key, self.left, self.right = key, left, right

def inorder(node):
    if node:
        yield from inorder(node.left)
        yield node.key
        yield from inorder(node.right)

root = Node(5, Node(3, Node(1)), Node(8, None, Node(9)))
print(list(inorder(root)))', 3),
  ('sc-net-004', 'starter-net', 'What does this print?', '`https api.example.com 8443 /v1/users id=7`. A URL names the scheme, host, optional port, path, and query. The `#fragment` never leaves the browser.', 'easy', 'python', 'from urllib.parse import urlparse

u = urlparse("https://api.example.com:8443/v1/users?id=7#top")
print(u.scheme, u.hostname, u.port, u.path, u.query)', 3),
  ('sc-net2-004', 'starter-net-2', '**PUT** is idempotent but **POST** isn''t. What does that mean?', 'Sending the same PUT twice leaves the server as one PUT would. Sending a POST twice usually creates two things, like two orders.', 'medium', null, null, 3),
  ('sc-oop-004', 'starter-oop', 'What does a subclass inherit?', 'Its superclass''s **properties and methods**. It can add new ones and override existing ones.', 'easy', null, null, 3),
  ('sc-oop2-004', 'starter-oop-2', 'What is the **Strategy** pattern?', 'Interchangeable algorithms behind one interface, picked at runtime: different sort orders or payment methods passed in as a protocol.', 'medium', null, null, 3),
  ('sc-os-004', 'starter-os', 'What does `t.join()` do here?', 'It **blocks** the calling thread until `t` finishes, so the program waits for `work` to print before it continues.', 'easy', 'python', 'import threading

def work(name):
    print(f"hello from {name}")

t = threading.Thread(target=work, args=("worker",))
t.start()
t.join()', 3),
  ('sc-os2-004', 'starter-os-2', 'What does this print?', '`400000`, every time. The lock makes `count += 1` (read, add, write) happen as one step. Without it, threads could overwrite each other''s updates.', 'easy', 'python', 'import threading

count = 0
lock = threading.Lock()

def work():
    global count
    for _ in range(100_000):
        with lock:
            count += 1

threads = [threading.Thread(target=work) for _ in range(4)]
for t in threads:
    t.start()
for t in threads:
    t.join()
print(count)', 3),
  ('sc-py-004', 'starter-python', 'What does `def greet(name="you")` mean?', '`name` has a **default value**: `greet()` works with no argument, and `greet("Ana")` overrides it.', 'easy', null, null, 3),
  ('sc-py2-004', 'starter-python-2', 'What does `with open(path) as f:` guarantee?', 'The file is closed when the block ends, even if an exception is raised inside it.', 'medium', null, null, 3),
  ('sc-swift-004', 'starter-swift', 'What does `if let` do?', 'Unwraps an optional **only if it has a value**, binding it to a new constant inside the `if`. If it''s nil, the body is skipped.', 'easy', null, null, 3),
  ('sc-algo-005', 'starter-algo', 'What are merge sort''s time and extra-space costs?', '**O(n log n)** time in every case, plus **O(n)** extra space for merging.', 'medium', null, null, 4),
  ('sc-algo2-005', 'starter-algo-2', 'What does this print?', '`[1, 2, 3, 4, 9, 10, 12]`. This is merge sort''s **merge** step: walk both sorted lists and always take the smaller head. It runs in O(len(a) + len(b)).', 'medium', 'python', 'def merge(a, b):
    out, i, j = [], 0, 0
    while i < len(a) and j < len(b):
        if a[i] <= b[j]:
            out.append(a[i])
            i += 1
        else:
            out.append(b[j])
            j += 1
    return out + a[i:] + b[j:]

print(merge([1, 4, 9], [2, 3, 10, 12]))', 4),
  ('sc-db-005', 'starter-db', 'What''s the difference between `WHERE` and `HAVING`?', '`WHERE` filters **rows** before grouping. `HAVING` filters **groups** after `GROUP BY`, so it can use aggregates like `COUNT(*)`.', 'medium', null, null, 4),
  ('sc-db2-005', 'starter-db-2', 'What does this print?', '`[(''ana'', 30.0), (''cy'', 7.0)]`. `GROUP BY` makes one row per customer, `SUM` adds their totals, and `HAVING` filters the groups. Bo''s total is exactly 6, so Bo is dropped.', 'medium', 'python', 'import sqlite3

db = sqlite3.connect(":memory:")
db.execute("CREATE TABLE orders (customer TEXT, total REAL)")
db.executemany("INSERT INTO orders VALUES (?, ?)",
               [("ana", 10), ("bo", 5), ("ana", 20), ("bo", 1), ("cy", 7)])
rows = db.execute("""
    SELECT customer, SUM(total) FROM orders
    GROUP BY customer HAVING SUM(total) > 6
    ORDER BY customer
""").fetchall()
print(rows)', 4),
  ('sc-ds-005', 'starter-ds', 'What are the **average** and **worst-case** costs of a hash table lookup?', 'Average **O(1)**. Worst case **O(n)**, when many keys collide in the same bucket.', 'medium', null, null, 4),
  ('sc-ds2-005', 'starter-ds-2', 'In what order does this breadth-first search visit the nodes?', '`ABCDE`. BFS uses a **queue**: it visits A, then A''s neighbors (B, C), then theirs (D, E). The `seen` set stops D from being queued twice.', 'medium', 'python', 'from collections import deque

graph = {"A": ["B", "C"], "B": ["D"], "C": ["D", "E"], "D": [], "E": []}
seen, order, queue = {"A"}, [], deque(["A"])
while queue:
    node = queue.popleft()
    order.append(node)
    for nxt in graph[node]:
        if nxt not in seen:
            seen.add(nxt)
            queue.append(nxt)
print("".join(order))', 4),
  ('sc-net-005', 'starter-net', 'TCP or UDP for downloading a file, and why?', '**TCP**: it guarantees every byte arrives, in order, by retransmitting lost packets. A file with a missing chunk is useless.', 'medium', null, null, 4),
  ('sc-net2-005', 'starter-net-2', 'What does **HTTPS** add to HTTP?', 'TLS: the connection is encrypted, the server proves who it is with a certificate, and changes in transit are detected.', 'medium', null, null, 4),
  ('sc-oop-005', 'starter-oop', 'What does this print?', '`[9, 3.1]`. **Polymorphism**: the same `area()` call runs each class''s own version, and the caller doesn''t need to know which shape it has.', 'medium', 'python', 'class Shape:
    def area(self):
        raise NotImplementedError

class Square(Shape):
    def __init__(self, side):
        self.side = side

    def area(self):
        return self.side ** 2

class Circle(Shape):
    def __init__(self, r):
        self.r = r

    def area(self):
        return round(3.14159 * self.r ** 2, 1)

print([s.area() for s in [Square(3), Circle(1)]])', 4),
  ('sc-oop2-005', 'starter-oop-2', 'What is the **Adapter** pattern?', 'A wrapper that makes one interface look like another, so code that expects interface A can use a class that only offers B.', 'medium', null, null, 4),
  ('sc-os-005', 'starter-os', 'What is a **race condition**?', 'A bug where the result depends on how threads are timed while they access shared data. For example, two threads running `count += 1` at the same time can lose an update.', 'medium', null, null, 4),
  ('sc-os2-005', 'starter-os-2', 'Concurrency vs parallelism?', '**Concurrency** is structuring work as tasks whose progress overlaps in time. **Parallelism** is tasks running at the same instant on different cores. A single core can be concurrent but not parallel.', 'medium', null, null, 4),
  ('sc-py-005', 'starter-python', 'What does this print?', '`[1, 2, 3] [1, 2]`. `b = a` is a second name for the **same** list, so appending through `b` changes `a`. `a[:]` made a separate (shallow) copy.', 'medium', 'python', 'a = [1, 2]
b = a
c = a[:]
b.append(3)
print(a, c)', 4),
  ('sc-py2-005', 'starter-python-2', 'What does `d.get(key, default)` do?', 'Returns the value for `key`, or `default` (None if you leave it out) when the key is missing, instead of raising `KeyError`.', 'medium', null, null, 4),
  ('sc-swift-005', 'starter-swift', 'What does this print?', '`0 5`. Structs are **value types**, so `p2` is a copy and `p1` is unchanged. Classes are **reference types**: `b1` and `b2` are the same object.', 'medium', 'swift', 'struct Point { var x = 0 }
class Box { var x = 0 }

let p1 = Point()
var p2 = p1
p2.x = 5

let b1 = Box()
let b2 = b1
b2.x = 5

print(p1.x, b1.x)', 4),
  ('sc-algo-006', 'starter-algo', 'Why is quicksort''s worst case O(n²)?', 'Bad pivots, such as always picking the smallest element of sorted input, split n items into 0 and n − 1. That gives n levels of O(n) work. Random or median-of-three pivots make this unlikely.', 'medium', null, null, 5),
  ('sc-algo2-006', 'starter-algo-2', 'Why is quicksort''s worst case O(n²)?', 'If the pivot is always the smallest or largest element (say, the first element of sorted input), each partition removes just one element: n levels of O(n) work. Random or median-of-three pivots make that very unlikely.', 'medium', null, null, 5),
  ('sc-db-006', 'starter-db', 'What does an **index** speed up, and what does it cost?', 'Lookups, joins, and sorts on the indexed columns: a B-tree index finds rows in O(log n) instead of scanning the whole table. The cost is extra storage and slower `INSERT`, `UPDATE`, and `DELETE`, because the index must be updated too.', 'medium', null, null, 5),
  ('sc-db2-006', 'starter-db-2', 'INNER JOIN vs LEFT JOIN, in one sentence?', 'An INNER JOIN keeps only rows that match in **both** tables; a LEFT JOIN keeps **every** left row and fills in NULLs where the right side has no match.', 'medium', null, null, 5),
  ('sc-ds-006', 'starter-ds', 'What does this print, and why use `deque` instead of a list here?', '`[2, 3, 4]`. `deque.popleft()` is **O(1)**, while `list.pop(0)` is O(n) because every remaining element shifts left.', 'medium', 'python', 'from collections import deque

q = deque([1, 2, 3])
q.append(4)
q.popleft()
print(list(q))', 5),
  ('sc-ds2-006', 'starter-ds-2', 'Adjacency list or adjacency matrix: which answers "is there an edge u→v?" in O(1)?', 'The **adjacency matrix**: just read `matrix[u][v]`. A list must scan u''s neighbors (O(degree)), but it needs only O(V + E) space instead of O(V²), which wins for sparse graphs.', 'medium', null, null, 5),
  ('sc-net-006', 'starter-net', 'Walk through the TCP three-way handshake.', 'The client sends **SYN**, the server replies **SYN-ACK**, and the client sends **ACK**. Both sides have now agreed on starting sequence numbers, so data can flow.', 'medium', null, null, 5),
  ('sc-net2-006', 'starter-net-2', 'What is a **cookie**?', 'A small piece of data the server asks the browser to store (`Set-Cookie`). The browser sends it back with later requests to that site, often to keep you signed in.', 'medium', null, null, 5),
  ('sc-oop-006', 'starter-oop', 'What does this print?', '`Hello, Hola`. Both types conform to the `Greeter` **protocol** (an interface), so they can share one array and be used the same way.', 'medium', 'swift', 'protocol Greeter {
    func greet() -> String
}

struct English: Greeter {
    func greet() -> String { "Hello" }
}

struct Spanish: Greeter {
    func greet() -> String { "Hola" }
}

let greeters: [any Greeter] = [English(), Spanish()]
print(greeters.map { $0.greet() }.joined(separator: ", "))', 5),
  ('sc-oop2-006', 'starter-oop-2', 'What is the **Decorator** pattern?', 'Wrapping an object in another with the same interface that adds behavior, like logging or caching, before passing calls through.', 'medium', null, null, 5),
  ('sc-os-006', 'starter-os', 'Two threads each run `add()`. What does `lock_guard` guarantee?', 'Only one thread increments `count` at a time, and the mutex unlocks automatically when `lock` goes out of scope. The final `count` is always `2000`.', 'medium', 'cpp', 'std::mutex m;
int count = 0;

void add() {
    for (int i = 0; i < 1000; ++i) {
        std::lock_guard<std::mutex> lock(m);
        ++count;
    }
}', 5),
  ('sc-os2-006', 'starter-os-2', 'Give a two-thread deadlock example.', 'Thread 1 holds lock A and waits for B; thread 2 holds B and waits for A. Neither can move. Always taking locks in one global order prevents it.', 'medium', null, null, 5),
  ('sc-py-006', 'starter-python', 'What does this print?', '`3 [2, 1]`. A **generator** produces values lazily: `next` takes the first one, and `list` drains the rest.', 'medium', 'python', 'def countdown(n):
    while n > 0:
        yield n
        n -= 1

gen = countdown(3)
print(next(gen), list(gen))', 5),
  ('sc-py2-006', 'starter-python-2', 'What does `*` do in `first, *rest = [1, 2, 3]`?', 'Collects the leftovers: `first` is 1 and `rest` is `[2, 3]`. In a call, `f(*args)` spreads a list into separate arguments.', 'medium', null, null, 5),
  ('sc-swift-006', 'starter-swift', 'What does this print?', '`24`. `filter` keeps 72, 95, and 88; `map` turns them into 7, 9, and 8 (integer division); `reduce(0, +)` adds them up.', 'medium', 'swift', 'let scores = [72, 95, 88, 61]
let result = scores.filter { $0 >= 70 }.map { $0 / 10 }.reduce(0, +)
print(result)', 5),
  ('sc-algo-007', 'starter-algo', 'What does `fib(6)` return, and why is this faster than naive recursion?', '`8` (0, 1, 1, 2, 3, 5, **8**). It runs in O(n) time with O(1) space. Naive recursive `fib` recomputes the same subproblems and takes exponential time.', 'medium', 'java', 'static int fib(int n) {
    int a = 0, b = 1;
    for (int i = 0; i < n; i++) {
        int next = a + b;
        a = b;
        b = next;
    }
    return a;
}', 6),
  ('sc-algo2-007', 'starter-algo-2', 'Which sort suits a *nearly* sorted array?', '**Insertion sort**. It does O(n + k) work, where k is the number of out-of-order pairs, so a few misplaced elements cost little.', 'medium', null, null, 6),
  ('sc-db-007', 'starter-db', 'Why use a `PreparedStatement` with `?` instead of building the SQL string yourself?', 'The parameters are sent separately from the SQL text, which prevents **SQL injection**. The database can also reuse the query plan.', 'medium', 'java', 'String sql = "SELECT name FROM users WHERE id = ?";
try (PreparedStatement ps = conn.prepareStatement(sql)) {
    ps.setInt(1, userId);
    try (ResultSet rs = ps.executeQuery()) {
        if (rs.next()) {
            System.out.println(rs.getString("name"));
        }
    }
}', 6),
  ('sc-db2-007', 'starter-db-2', 'What does this print?', '`[(''Bo'',)]`. The LEFT JOIN keeps every user, and users without orders get NULLs on the order side. `WHERE o.user_id IS NULL` is the classic "rows with no match" pattern.', 'medium', 'python', 'import sqlite3

db = sqlite3.connect(":memory:")
db.executescript("""
    CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT);
    CREATE TABLE orders (user_id INTEGER, item TEXT);
    INSERT INTO users VALUES (1, ''Ana''), (2, ''Bo''), (3, ''Cy'');
    INSERT INTO orders VALUES (1, ''book''), (1, ''pen''), (3, ''mug'');
""")
rows = db.execute("""
    SELECT u.name FROM users u
    LEFT JOIN orders o ON o.user_id = u.id
    WHERE o.user_id IS NULL
""").fetchall()
print(rows)', 6),
  ('sc-ds-007', 'starter-ds', 'Why is inserting at the head of a **singly linked list** O(1)?', 'You only create a node and point it at the old head. No elements move, unlike inserting at index 0 of an array.', 'medium', null, null, 6),
  ('sc-ds2-007', 'starter-ds-2', 'What is a *complete* binary tree, and why do heaps use one?', 'Every level is full except possibly the last, which fills left to right. That shape lets a heap live in a plain array with no pointers.', 'medium', null, null, 6),
  ('sc-net-007', 'starter-net', 'What does this print?', '`{"id": 7, "done": false, "tags": ["a", "b"]}`, then `True`. JSON is the usual body format for HTTP APIs: Python''s `False` becomes JSON `false`, and parsing it back gives `False`.', 'medium', 'python', 'import json

payload = {"id": 7, "done": False, "tags": ["a", "b"]}
text = json.dumps(payload)
print(text)
print(json.loads(text)["done"] is False)', 6),
  ('sc-net2-007', 'starter-net-2', 'What does **DNS** do when you open `example.com`?', 'Turns the name into an IP address by asking resolvers and the domain''s name servers, then caches the answer for its TTL.', 'medium', null, null, 6),
  ('sc-oop-007', 'starter-oop', 'What is composition, and why is it often preferred to inheritance?', 'An object **has** other objects and delegates to them (a Car has an Engine) instead of **being** a subclass. Classes stay small, and parts can be swapped without reshaping a hierarchy.', 'medium', null, null, 6),
  ('sc-oop2-007', 'starter-oop-2', 'What does **dependency injection** mean?', 'An object is handed what it depends on (usually in its initializer) instead of creating it, so tests can pass in fakes.', 'medium', null, null, 6),
  ('sc-os-007', 'starter-os', 'What is a **page fault**?', 'An access to a virtual page that isn''t in physical memory right now. The OS loads the page (for example, from disk), updates the page table, and retries the instruction.', 'medium', null, null, 6),
  ('sc-os2-007', 'starter-os-2', 'What does this print?', '`2`. An **actor** protects its state: outside calls are `await`ed and run one at a time, so `value` can''t be corrupted by a data race.', 'medium', 'swift', 'actor Counter {
    private var value = 0

    func increment() -> Int {
        value += 1
        return value
    }
}

let counter = Counter()
_ = await counter.increment()
print(await counter.increment())', 6),
  ('sc-py-007', 'starter-python', 'What do `*args` and `**kwargs` collect?', '`*args` gathers extra **positional** arguments into a tuple; `**kwargs` gathers extra **keyword** arguments into a dict.', 'medium', null, null, 6),
  ('sc-py2-007', 'starter-python-2', 'List comprehension vs generator expression?', '`[x * 2 for x in xs]` builds the whole list now. `(x * 2 for x in xs)` makes items one at a time as you loop, using little memory.', 'medium', null, null, 6),
  ('sc-swift-007', 'starter-swift', '`guard let` vs `if let`?', '`guard let` unwraps and **requires** its `else` to leave the scope (return, throw, break). The value stays available for the rest of the function, which avoids deep nesting.', 'medium', null, null, 6),
  ('sc-algo-008', 'starter-algo', 'What is **divide and conquer**?', 'Split a problem into smaller subproblems, solve them recursively, then **combine** the results. Merge sort and binary search both work this way.', 'medium', null, null, 7),
  ('sc-algo2-008', 'starter-algo-2', 'What does this print?', '`fig banana`. `sorted(by:)` takes a comparator; here shorter words come first, so the shortest is `fig` and the longest is `banana`.', 'medium', 'swift', 'let words = ["pear", "fig", "banana", "kiwi"]
let sorted = words.sorted { $0.count < $1.count }
print(sorted.first!, sorted.last!)', 7),
  ('sc-db-008', 'starter-db', 'What''s the difference between `INNER JOIN` and `LEFT JOIN`?', '`INNER JOIN` keeps only rows that have a match in both tables. `LEFT JOIN` keeps **every** row from the left table and fills in `NULL` where the right table has no match.', 'medium', null, null, 7),
  ('sc-db2-008', 'starter-db-2', 'What does `LIMIT 10 OFFSET 20` return?', 'Rows **21–30** of the result: skip 20, take 10. It''s used for paging. Add an `ORDER BY` so the pages stay stable.', 'medium', null, null, 7),
  ('sc-ds-008', 'starter-ds', 'What property defines a **binary search tree**?', 'For every node, keys in the left subtree are smaller and keys in the right subtree are larger. An in-order traversal therefore visits keys in sorted order.', 'medium', null, null, 7),
  ('sc-ds2-008', 'starter-ds-2', 'What does this print?', '`7 4`. In an array-backed binary heap, node `i`''s children are at `2i + 1` and `2i + 2`. Node 1 (value 3) has children at indexes 3 and 4.', 'medium', 'swift', 'let heap = [1, 3, 2, 7, 4, 5]
let i = 1
print(heap[2 * i + 1], heap[2 * i + 2])', 7),
  ('sc-net-008', 'starter-net', 'What does this print?', '`https://api.example.com/search?q=swift%20tips`. `URLComponents` builds URLs safely and **percent-encodes** the space. Gluing strings together by hand is how URLs break.', 'medium', 'swift', 'import Foundation

var parts = URLComponents()
parts.scheme = "https"
parts.host = "api.example.com"
parts.path = "/search"
parts.queryItems = [URLQueryItem(name: "q", value: "swift tips")]
print(parts.url!.absoluteString)', 7),
  ('sc-net2-008', 'starter-net-2', 'What is **CORS**?', 'A browser rule: a page can read a response from another origin only if that server allows it, with headers like `Access-Control-Allow-Origin`.', 'hard', null, null, 7),
  ('sc-oop-008', 'starter-oop', 'Overriding vs overloading?', '**Overriding**: a subclass replaces a superclass method with the same signature, chosen at runtime. **Overloading**: several methods share a name but take different parameters, chosen at compile time.', 'medium', null, null, 7),
  ('sc-oop2-008', 'starter-oop-2', 'What is the **Facade** pattern?', 'One simple interface in front of several complex subsystems, so callers don''t need to know how they fit together.', 'hard', null, null, 7),
  ('sc-os-008', 'starter-os', 'What are the four conditions for **deadlock**?', 'Mutual exclusion, hold and wait, no preemption, and circular wait. Breaking any one of them prevents deadlock.', 'medium', null, null, 7),
  ('sc-os2-008', 'starter-os-2', 'What is a semaphore with a count of 3 good for?', 'Letting **up to 3** threads into a section at once, for example to cap concurrent downloads. A count of 1 behaves like a lock.', 'medium', null, null, 7),
  ('sc-py-008', 'starter-python', 'Why write `with open(path) as f:`?', '`with` uses a **context manager**: the file is closed when the block ends, even if an exception is raised.', 'medium', null, null, 7),
  ('sc-py2-008', 'starter-python-2', 'What does this print?', '`[1]` then `[1, 2]`. The default list is created once, when the function is defined, so every call shares it. Use `items=None` and make the list inside.', 'hard', 'python', 'def add(item, items=[]):
    items.append(item)
    return items

print(add(1))
print(add(2))', 7),
  ('sc-swift-008', 'starter-swift', 'What is a protocol extension good for?', 'Giving **default implementations** to every conforming type at once. A type can still provide its own version.', 'medium', null, null, 7),
  ('sc-algo-009', 'starter-algo', 'When does **dynamic programming** apply?', 'When a problem has **overlapping subproblems** and **optimal substructure**. Store each subproblem''s answer (memoization or a table) so it''s computed only once.', 'hard', null, null, 8),
  ('sc-algo2-009', 'starter-algo-2', 'Counting sort runs in O(n + k). Why doesn''t that break the Ω(n log n) sorting bound?', 'That bound is for **comparison** sorts. Counting sort never compares elements; it counts how many of each key (0..<k) there are. It''s only practical when k is small.', 'hard', null, null, 8),
  ('sc-db-009', 'starter-db', 'Summarize **1NF**, **2NF**, and **3NF**.', '- **1NF**: atomic values, no repeating groups.
- **2NF**: no non-key column depends on only part of a composite key.
- **3NF**: no non-key column depends on another non-key column.', 'hard', null, null, 8),
  ('sc-db2-009', 'starter-db-2', 'What does `WHERE price > (SELECT AVG(price) FROM items)` do?', 'The **subquery** computes the average price once, and the outer query keeps only the items priced above it.', 'hard', null, null, 8),
  ('sc-ds-009', 'starter-ds', 'Why can a binary search tree degrade to O(n) search, and how do balanced trees prevent it?', 'Inserting keys in sorted order builds a chain of height n. **AVL** and **red-black** trees rebalance with rotations so the height stays O(log n).', 'hard', null, null, 8),
  ('sc-ds2-009', 'starter-ds-2', 'Why is DFS a natural fit for finding cycles in a directed graph?', 'DFS tracks the current path. Reaching a node that''s **still on the path** (a back edge) means there''s a cycle. Nodes that are already finished can''t be part of a new one.', 'hard', null, null, 8),
  ('sc-net-009', 'starter-net', 'Why does HTTPS need both a certificate and a key exchange?', 'The **certificate** proves you reached the real server (a CA vouches for its public key). The **key exchange** (e.g. ECDHE) creates fresh session keys, so past traffic stays private even if the server''s key later leaks.', 'hard', null, null, 8),
  ('sc-net2-009', 'starter-net-2', 'What does this send, and what should the server reply when it creates the user?', 'A **POST** with a JSON body (`Content-Type: application/json`). A server that creates the user usually replies **201 Created**, often with a `Location` header for the new user.', 'hard', 'python', 'import requests

r = requests.post(
    "https://api.example.com/users",
    json={"name": "Ada"},
)
print(r.status_code)', 8),
  ('sc-oop-009', 'starter-oop', 'What does this print?', '`Woof animal`. `speak` is **virtual**, so the call reaches Dog''s override through an `Animal&`. `name` isn''t virtual, so the reference''s static type (Animal) decides.', 'hard', 'cpp', '#include <iostream>
#include <string>

struct Animal {
    virtual std::string speak() const { return "..."; }
    std::string name() const { return "animal"; }
    virtual ~Animal() = default;
};

struct Dog : Animal {
    std::string speak() const override { return "Woof"; }
    std::string name() const { return "dog"; }
};

int main() {
    Dog d;
    const Animal& a = d;
    std::cout << a.speak() << " " << a.name() << "\n";
}', 8),
  ('sc-oop2-009', 'starter-oop-2', 'Which pattern is this?', '**Strategy**: `Checkout` holds one interchangeable `Discount` and can swap it without changing its own code.', 'hard', 'swift', 'protocol Discount { func apply(to price: Double) -> Double }
struct NoDiscount: Discount { func apply(to price: Double) -> Double { price } }
struct Sale: Discount { func apply(to price: Double) -> Double { price * 0.8 } }

struct Checkout {
    var discount: Discount
    func total(_ price: Double) -> Double { discount.apply(to: price) }
}', 8),
  ('sc-os-009', 'starter-os', 'How does **round-robin** scheduling work, and what does the time quantum trade off?', 'Each ready task runs for a fixed time slice, then moves to the back of the queue. A shorter quantum improves responsiveness but adds more context-switch overhead.', 'hard', null, null, 8),
  ('sc-os2-009', 'starter-os-2', 'What does this print?', '`[2, 4, 6]`. `queue.Queue` is thread-safe, which makes it the classic **producer–consumer** channel. The `None` sentinel tells the consumer to stop, and `join()` waits for it.', 'hard', 'python', 'import queue
import threading

q = queue.Queue()
results = []

def consumer():
    while (item := q.get()) is not None:
        results.append(item * 2)

t = threading.Thread(target=consumer)
t.start()
for n in [1, 2, 3]:
    q.put(n)
q.put(None)  # sentinel: tells the consumer to stop
t.join()
print(results)', 8),
  ('sc-py-009', 'starter-python', 'What does this print?', '`[1, 2] [1, 2]`. The default list is created **once**, when `def` runs, and every call shares it, so both calls return the same list. Use `bucket=None` and make a new list inside.', 'hard', 'python', 'def add(item, bucket=[]):
    bucket.append(item)
    return bucket

print(add(1), add(2))', 8),
  ('sc-py2-009', 'starter-python-2', 'What does `if __name__ == "__main__":` do?', 'Runs the block only when the file is run directly, not when it''s imported as a module.', 'hard', null, null, 8),
  ('sc-swift-009', 'starter-swift', 'What does this print?', '`freed`, then `end`. `[weak self]` stops the stored closure from keeping the object alive. With a strong capture, object and closure would form a **retain cycle**, and `deinit` would never run.', 'hard', 'swift', 'final class Downloader {
    var onFinish: (() -> Void)?
    var name = "dl"

    func start() {
        onFinish = { [weak self] in print(self?.name ?? "gone") }
    }

    deinit { print("freed") }
}

var downloader: Downloader? = Downloader()
downloader?.start()
downloader = nil
print("end")', 8),
  ('sc-algo-010', 'starter-algo', 'Why compute `mid` as `lo + (hi - lo) / 2` instead of `(lo + hi) / 2`?', '`lo + hi` can **overflow** when the indices are large. `lo + (hi - lo) / 2` gives the same midpoint without ever exceeding `hi`.', 'hard', 'swift', 'func search(_ a: [Int], _ target: Int) -> Int? {
    var lo = 0, hi = a.count - 1
    while lo <= hi {
        let mid = lo + (hi - lo) / 2
        if a[mid] == target { return mid }
        if a[mid] < target { lo = mid + 1 } else { hi = mid - 1 }
    }
    return nil
}', 9),
  ('sc-algo2-010', 'starter-algo-2', 'What does this print?', '`1 4 3`. `lower_bound` finds the first element ≥ 3 and `upper_bound` the first element > 3, both by binary search. Their difference counts the 3s in **O(log n)**.', 'hard', 'cpp', '#include <algorithm>
#include <iostream>
#include <vector>

int main() {
    std::vector<int> v = {1, 3, 3, 3, 8};
    auto lo = std::lower_bound(v.begin(), v.end(), 3) - v.begin();
    auto hi = std::upper_bound(v.begin(), v.end(), 3) - v.begin();
    std::cout << lo << " " << hi << " " << hi - lo << "\n";
}', 9),
  ('sc-db-010', 'starter-db', 'What does this print, and which ACID property does it show?', '`100`. `with db:` wraps the block in a transaction. The exception triggers a **rollback**, so the debit never happens. That''s **atomicity**.', 'hard', 'python', 'import sqlite3

db = sqlite3.connect(":memory:")
db.execute("CREATE TABLE acct (id INTEGER PRIMARY KEY, bal INTEGER)")
db.executemany("INSERT INTO acct VALUES (?, ?)", [(1, 100), (2, 0)])
db.commit()

try:
    with db:
        db.execute("UPDATE acct SET bal = bal - 50 WHERE id = 1")
        raise RuntimeError("crash mid-transfer")
except RuntimeError:
    pass

print(db.execute("SELECT bal FROM acct WHERE id = 1").fetchone()[0])', 9),
  ('sc-db2-010', 'starter-db-2', 'What does this print?', '`[(''blue'', ''cy''), (''red'', ''bo'')]`. `ROW_NUMBER() OVER (PARTITION BY team …)` numbers rows within each team by points, so `rank = 1` picks each team''s top scorer. Unlike GROUP BY, a window function keeps every row.', 'hard', 'python', 'import sqlite3

db = sqlite3.connect(":memory:")
db.execute("CREATE TABLE scores (player TEXT, team TEXT, points INTEGER)")
db.executemany("INSERT INTO scores VALUES (?, ?, ?)", [
    ("ana", "red", 30), ("bo", "red", 50), ("cy", "blue", 40), ("di", "blue", 20)])
rows = db.execute("""
    SELECT team, player FROM (
        SELECT team, player,
               ROW_NUMBER() OVER (PARTITION BY team ORDER BY points DESC) AS rank
        FROM scores)
    WHERE rank = 1 ORDER BY team
""").fetchall()
print(rows)', 9),
  ('sc-ds-010', 'starter-ds', 'What does this print? What data structure backs `PriorityQueue`?', '`1 3`. It''s a **binary min-heap**: `poll()` removes the minimum in O(log n), and `peek()` reads the new minimum in O(1).', 'hard', 'java', 'PriorityQueue<Integer> pq = new PriorityQueue<>();
pq.add(5);
pq.add(1);
pq.add(3);
System.out.println(pq.poll() + " " + pq.peek());', 9),
  ('sc-ds2-010', 'starter-ds-2', 'What does this print, and what algorithm is it?', '`[''shop'', ''cook'', ''eat'', ''wash'']`. It''s **Kahn''s algorithm** for topological sort: repeatedly take a task whose dependencies are all done (in-degree 0). If some task never reaches 0, the graph has a cycle.', 'hard', 'python', 'from collections import deque

deps = {"shop": [], "cook": ["shop"], "eat": ["cook"], "wash": ["eat", "cook"]}
indegree = {task: len(before) for task, before in deps.items()}
unlocks = {task: [] for task in deps}
for task, before in deps.items():
    for b in before:
        unlocks[b].append(task)

queue = deque(t for t, d in indegree.items() if d == 0)
order = []
while queue:
    task = queue.popleft()
    order.append(task)
    for nxt in unlocks[task]:
        indegree[nxt] -= 1
        if indegree[nxt] == 0:
            queue.append(nxt)
print(order)', 9),
  ('sc-net-010', 'starter-net', 'What is head-of-line blocking, and how does HTTP/3 avoid it?', 'On one TCP connection, a lost packet stalls **everything** behind it until it''s resent. HTTP/3 runs on QUIC (over UDP), which orders each stream separately, so a loss only stalls its own stream.', 'hard', null, null, 9),
  ('sc-net2-010', 'starter-net-2', 'Why does **HTTP/2** load a page with many files faster than HTTP/1.1?', 'It multiplexes: many requests and responses share one connection at the same time instead of waiting in line. It also compresses headers.', 'hard', null, null, 9),
  ('sc-oop-010', 'starter-oop', 'What does the Liskov Substitution Principle require?', 'Code that works with a base type must keep working with **any subclass**. A subclass can''t demand more from callers or break the base type''s promises.', 'hard', null, null, 9),
  ('sc-oop2-010', 'starter-oop-2', 'Why is "composition over inheritance" common advice?', 'Building objects from smaller parts they hold (has-a) keeps classes loosely coupled and easy to change. Deep inheritance (is-a) ties subclasses to every detail of their parents.', 'hard', null, null, 9),
  ('sc-os-010', 'starter-os', 'Why isn''t `count++` safe without `synchronized`?', '`count++` is a **read–modify–write**. Two threads can read the same value and both write back value + 1, so one increment is lost. `synchronized` lets only one thread run the method at a time.', 'hard', 'java', 'class Counter {
    private int count = 0;

    synchronized void increment() {
        count++;
    }

    synchronized int get() {
        return count;
    }
}', 9),
  ('sc-os2-010', 'starter-os-2', 'Why isn''t `count += 1` atomic?', 'It''s three steps: **read** count, **add** 1, **write** it back. Two threads can read the same old value, and one increment is lost.', 'hard', null, null, 9),
  ('sc-py-010', 'starter-python', 'What does this print?', '`HI ANA! greet`. A **decorator** wraps a function to add behavior. `functools.wraps` copies the original''s name and docstring onto the wrapper.', 'hard', 'python', 'import functools

def shout(func):
    @functools.wraps(func)
    def wrapper(*args, **kwargs):
        return func(*args, **kwargs).upper() + "!"
    return wrapper

@shout
def greet(name):
    return f"hi {name}"

print(greet("ana"), greet.__name__)', 9),
  ('sc-py2-010', 'starter-python-2', 'What does this print?', '`[(''i'', 4), (''s'', 4)]`. `Counter` counts each letter, and `most_common(2)` returns the two highest. Ties keep first-seen order, and `i` comes before `s`.', 'hard', 'python', 'from collections import Counter

c = Counter("mississippi")
print(c.most_common(2))', 9),
  ('sc-swift-010', 'starter-swift', 'What does `@escaping` mean?', 'The closure may be stored and **called after the function returns**, like a completion handler. Escaping closures must use `self` explicitly, which makes possible retain cycles visible.', 'hard', null, null, 9),
  ('sc-algo-011', 'starter-algo', 'Why can''t a comparison sort beat O(n log n) in the worst case?', 'There are n! possible orderings, and each comparison has only 2 outcomes. A decision tree that tells them all apart needs height ≥ log₂(n!), which is Ω(n log n).', 'hard', null, null, 10),
  ('sc-algo2-011', 'starter-algo-2', 'How does quickselect find the k-th smallest element in O(n) on average?', 'It partitions like quicksort but recurses into **only the side** that contains index k. The expected work is n + n/2 + n/4 + … ≈ 2n.', 'hard', null, null, 10),
  ('sc-db-011', 'starter-db', 'What anomaly does the `READ COMMITTED` isolation level still allow?', '**Non-repeatable reads**: reading the same row twice in one transaction can return different values if another transaction commits in between. It does prevent dirty reads.', 'hard', null, null, 10),
  ('sc-db2-011', 'starter-db-2', 'Why can `WHERE LOWER(email) = ?` be slow even though `email` has an index?', 'Wrapping the column in a function means the plain index on `email` can''t be used, so the database **scans every row**. Use an index on `LOWER(email)` or store emails already lowercased.', 'hard', null, null, 10),
  ('sc-ds-011', 'starter-ds', 'What is the amortized cost of appending to a dynamic array, and why?', '**O(1) amortized**. When the array is full, its capacity doubles and all n items are copied, which costs O(n). Doublings are rare enough that n appends cost O(n) in total.', 'hard', null, null, 10),
  ('sc-ds2-011', 'starter-ds-2', 'How do AVL and red-black trees guarantee O(log n) search?', 'They **rebalance** with rotations after inserts and deletes, keeping the height O(log n). A plain BST fed sorted keys degrades into a chain of height n.', 'hard', null, null, 10),
  ('sc-net-011', 'starter-net', 'What does this print?', '`64 192.168.1.63 False`. A /26 leaves 6 host bits: 2⁶ = 64 addresses, .0 through .63 (the broadcast). So .70 is in the next subnet.', 'hard', 'python', 'import ipaddress

net = ipaddress.ip_network("192.168.1.0/26")
print(net.num_addresses, net.broadcast_address, ipaddress.ip_address("192.168.1.70") in net)', 10),
  ('sc-oop-011', 'starter-oop', 'What does this print?', '`DBCA [''D'', ''B'', ''C'', ''A'', ''object'']`. Python resolves the diamond with its **method resolution order** (C3 linearization). Each `super()` moves to the next class in the MRO, so `A` runs only once.', 'hard', 'python', 'class A:
    def hello(self):
        return "A"

class B(A):
    def hello(self):
        return "B" + super().hello()

class C(A):
    def hello(self):
        return "C" + super().hello()

class D(B, C):
    def hello(self):
        return "D" + super().hello()

print(D().hello(), [k.__name__ for k in D.__mro__])', 10),
  ('sc-os-011', 'starter-os', 'What is **thrashing**?', 'When running processes need more pages than fit in RAM, the system spends most of its time handling page faults and swapping instead of doing useful work.', 'hard', null, null, 10),
  ('sc-os2-011', 'starter-os-2', 'What is a livelock?', 'Threads keep **reacting to each other** (for example, both backing off and retrying in lockstep), so they stay busy but make no progress. Random backoff usually breaks the pattern.', 'hard', null, null, 10),
  ('sc-py-011', 'starter-python', 'What does this print?', '`[2, 2, 2]`, then `[0, 1, 2]`. The lambdas look up `i` when they''re **called**, after the loop ended at 2. Binding it as a default (`i=i`) captures each value.', 'hard', 'python', 'funcs = [lambda: i for i in range(3)]
print([f() for f in funcs])

fixed = [lambda i=i: i for i in range(3)]
print([f() for f in fixed])', 10),
  ('sc-swift-011', 'starter-swift', 'What does this print?', '`9 pear true`. One **generic** function works for any `Comparable` type: Ints, Strings (compared alphabetically), and it returns nil for an empty array.', 'hard', 'swift', 'func largest<T: Comparable>(_ items: [T]) -> T? {
    guard var best = items.first else { return nil }
    for item in items.dropFirst() where item > best {
        best = item
    }
    return best
}

print(largest([3, 9, 4])!, largest(["pear", "apple"])!, largest([Int]()) == nil)', 10),
  ('sc-algo-012', 'starter-algo', 'What does this print?', '`4 at 2`. After sorting, `v` is `1 2 4 5`. `lower_bound` returns the first element **not less than** 3, which is `4` at index 2, in O(log n).', 'hard', 'cpp', 'std::vector<int> v = {5, 1, 4, 2};
std::sort(v.begin(), v.end());
auto it = std::lower_bound(v.begin(), v.end(), 3);
std::cout << *it << " at " << (it - v.begin());', 11),
  ('sc-algo2-012', 'starter-algo-2', 'What does this print?', '`[7, 8, 15] [99, 63]`. `heapq` keeps a heap of size k, so finding the k smallest or largest costs **O(n log k)**, cheaper than a full sort when k is small.', 'hard', 'python', 'import heapq

scores = [42, 7, 99, 15, 63, 8]
print(heapq.nsmallest(3, scores), heapq.nlargest(2, scores))', 11),
  ('sc-db-012', 'starter-db', 'How is `byEmail` like a database index?', 'It''s a separate structure keyed by the lookup column. Finding a row drops from a full scan (**O(n)**) to O(1) here (O(log n) for a B-tree index). The cost is extra memory, and the index must be kept up to date on every write.', 'hard', 'swift', 'struct User { let id: Int; let email: String }
let users = (1...100_000).map { User(id: $0, email: "u\($0)@x.io") }

// Without an index: scan every row.
let slow = users.first { $0.email == "u99999@x.io" }

// With an "index": a hash map from email to row.
let byEmail = Dictionary(uniqueKeysWithValues: users.map { ($0.email, $0) })
let fast = byEmail["u99999@x.io"]', 11),
  ('sc-db2-012', 'starter-db-2', 'What does this print?', '`[(100,), (20,)]`. Ana''s balance would go negative, so the CHECK fails and the whole transaction **rolls back**, including Bo''s +50. That''s atomicity: all or nothing.', 'hard', 'python', 'import sqlite3

db = sqlite3.connect(":memory:")
db.execute("CREATE TABLE accounts (name TEXT PRIMARY KEY, balance INTEGER CHECK (balance >= 0))")
db.executemany("INSERT INTO accounts VALUES (?, ?)", [("ana", 100), ("bo", 20)])
db.commit()
try:
    with db:  # one transaction: commit on success, roll back on error
        db.execute("UPDATE accounts SET balance = balance + 50 WHERE name = ''bo''")
        db.execute("UPDATE accounts SET balance = balance - 150 WHERE name = ''ana''")
except sqlite3.IntegrityError:
    pass
print(db.execute("SELECT balance FROM accounts ORDER BY name").fetchall())', 11),
  ('sc-ds-012', 'starter-ds', 'What does this print?', '`203`. `counts["z"]` *inserts* a default `0` for the missing key, so the size becomes 3. Use `find` or `contains` to look up a key without inserting it.', 'hard', 'cpp', 'std::unordered_map<std::string, int> counts;
for (const auto& w : {"a", "b", "a"}) {
    counts[w]++;
}
std::cout << counts["a"] << counts["z"] << counts.size();', 11),
  ('sc-ds2-012', 'starter-ds-2', 'What does this print?', '`1 0`. This is **union-find** (disjoint sets) with path compression: 0, 1, 3, and 4 end up in one set and 2 stays alone. It''s the core of Kruskal''s minimum-spanning-tree algorithm.', 'hard', 'cpp', '#include <iostream>
#include <vector>

std::vector<int> parent;

int find(int x) { return parent[x] == x ? x : parent[x] = find(parent[x]); }
void unite(int a, int b) { parent[find(a)] = find(b); }

int main() {
    parent = {0, 1, 2, 3, 4};
    unite(0, 1);
    unite(3, 4);
    unite(1, 4);
    std::cout << (find(0) == find(3)) << " " << (find(2) == find(0)) << "\n";
}', 11),
  ('sc-net-012', 'starter-net', 'Why are retries of a POST request risky?', 'POST isn''t **idempotent**: if the response was lost, retrying may create the order twice. APIs often accept an idempotency key so the server can recognize a repeat.', 'hard', null, null, 11),
  ('sc-oop-012', 'starter-oop', 'What is dependency injection?', 'Passing an object''s collaborators **in** (for example through its initializer) instead of creating them inside. It makes code easy to test with fakes and keeps it depending on abstractions.', 'hard', null, null, 11),
  ('sc-os-012', 'starter-os', 'What does this print, and what role does the serial `queue` play?', '`100`. `concurrentPerform` runs iterations in parallel. Sending every `total += 1` through the serial queue makes the updates happen one at a time, so there''s no data race.', 'hard', 'swift', 'let queue = DispatchQueue(label: "counter")
var total = 0

DispatchQueue.concurrentPerform(iterations: 100) { _ in
    queue.sync { total += 1 }
}
print(total)', 11),
  ('sc-os2-012', 'starter-os-2', 'What does this print?', '`200000`. `std::atomic<int>` makes `count++` a single indivisible operation, so no increments are lost and no mutex is needed. More complex shared state still needs a lock.', 'hard', 'cpp', '#include <atomic>
#include <iostream>
#include <thread>
#include <vector>

int main() {
    std::atomic<int> count{0};
    std::vector<std::thread> threads;
    for (int t = 0; t < 4; ++t)
        threads.emplace_back([&] { for (int i = 0; i < 50000; ++i) count++; });
    for (auto& th : threads) th.join();
    std::cout << count << "\n";
}', 11),
  ('sc-py-012', 'starter-python', 'What does the GIL mean for CPU-bound threads in CPython?', 'Only one thread runs Python bytecode at a time, so CPU-heavy threads don''t speed up. Use `multiprocessing` (or native code) for parallel CPU work; threads still help while waiting on I/O.', 'hard', null, null, 11),
  ('sc-swift-012', 'starter-swift', 'What does an `actor` guarantee?', 'Its mutable state is **isolated**: only one task touches it at a time. Outside callers must `await`, and the compiler rejects unsynchronized access, which rules out data races.', 'hard', null, null, 11)
on conflict (id) do update set deck_key = excluded.deck_key, prompt = excluded.prompt, answer = excluded.answer, difficulty = excluded.difficulty, code_language = excluded.code_language, code_source = excluded.code_source, sort_index = excluded.sort_index;

commit;
