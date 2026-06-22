// ============================================================================
// ParLibX Bookshop — Book Availability Checker
// ============================================================================
// A single-screen Flutter app that connects to a Supabase "books" table.
//
// FLUTTER CONCEPT — Packages:
//   We import two packages:
//   • 'package:flutter/material.dart'    → The core UI toolkit (widgets, themes, etc.)
//   • 'package:supabase_flutter/...'     → The official Supabase SDK for Flutter
//
// DART CONCEPT — `async` / `await`:
//   Dart uses Futures (like JS Promises) for asynchronous work. Mark a function
//   `async` and use `await` to pause until the Future completes.
// ============================================================================

import 'dart:async'; // Provides the Timer class for debouncing
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================================
// 1. MAIN ENTRY POINT
// ============================================================================
// Every Dart program starts here. We initialise Supabase, then launch the app.

Future<void> main() async {
  // FLUTTER CONCEPT — WidgetsFlutterBinding:
  //   This line ensures the Flutter engine is ready before we call any
  //   platform-specific code (like Supabase init). Always call this first
  //   when your main() is `async`.
  WidgetsFlutterBinding.ensureInitialized();

  // ──────────────────────────────────────────────────────────────────────────
  // ⬇️  PASTE YOUR SUPABASE CREDENTIALS HERE  ⬇️
  // ──────────────────────────────────────────────────────────────────────────
  // You'll find these in your Supabase dashboard:
  //   → Project Settings  →  API  →  Project URL  &  anon/public key
  await Supabase.initialize(
    url: 'https://nbbvcufhptrnaiicnfmx.supabase.co',
    publishableKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5iYnZjdWZocHRybmFpaWNuZm14Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIwOTkyMDcsImV4cCI6MjA5NzY3NTIwN30.rh1XlyAy2T_jNKUzHMQiftL7ehC6Yzr065vCHHQxkgk',
  );

  // Launch the root widget of the app.
  runApp(const BookshopApp());
}

// A handy shortcut to access the Supabase client anywhere in this file.
// `Supabase.instance.client` is the singleton created by `Supabase.initialize`.
final supabase = Supabase.instance.client;

// ============================================================================
// 2. ROOT WIDGET — BookshopApp  (StatelessWidget)
// ============================================================================
// FLUTTER CONCEPT — StatelessWidget:
//   A widget that does NOT hold any mutable state. It is built once and only
//   rebuilt when its *parent* rebuilds it with new parameters.
//   Use it for static configuration like theming & routing.

class BookshopApp extends StatelessWidget {
  const BookshopApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MaterialApp is the top-level wrapper that provides Material Design
    // defaults: navigation, theming, text direction, etc.
    return MaterialApp(
      title: 'The Library of Parliament',
      debugShowCheckedModeBanner: false, // hides the red "DEBUG" ribbon

      // ── Theme ──────────────────────────────────────────────────────────
      // We use Material 3 (useMaterial3: true) with a dark red colour seed.
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF8F230D),
        brightness: Brightness.light,
      ),

      home: const BookSearchScreen(), // the single screen of our app
    );
  }
}

// ============================================================================
// 3. MAIN SCREEN — BookSearchScreen  (StatefulWidget)
// ============================================================================
// FLUTTER CONCEPT — StatefulWidget:
//   A widget that CAN hold mutable state. It is actually TWO classes:
//     1. The widget class itself (immutable — just creates the State).
//     2. The State class (_BookSearchScreenState) which holds data that
//        can change over time and triggers UI rebuilds via `setState()`.

class BookSearchScreen extends StatefulWidget {
  const BookSearchScreen({super.key});

  // createState() is the factory that returns the mutable State object.
  @override
  State<BookSearchScreen> createState() => _BookSearchScreenState();
}

// ============================================================================
// 4. STATE CLASS — _BookSearchScreenState
// ============================================================================
// This is where all the action happens: the search input, Supabase queries,
// loading states, and the Add-Book bottom sheet.

class _BookSearchScreenState extends State<BookSearchScreen> {
  // ── Controllers & Timers ─────────────────────────────────────────────────
  // A TextEditingController lets us read/write the text inside a TextField
  // and listen for changes.
  final TextEditingController _searchController = TextEditingController();

  // Timer used for debouncing: we wait 500 ms after the user stops typing
  // before firing the Supabase query, to avoid flooding the database.
  Timer? _debounce;

  // ── State variables ──────────────────────────────────────────────────────
  // FLUTTER CONCEPT — setState():
  //   Calling setState(() { ... }) tells Flutter "some state changed — please
  //   re-run my build() method so the UI reflects the new data."
  //   NEVER mutate state without wrapping the change in setState().

  List<Map<String, dynamic>> _books = []; // the current search results
  bool _isLoading = false;                // true while a query is in-flight
  bool _hasSearched = false;              // distinguishes "welcome" vs "no results"

  // ── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    // Listen to every keystroke in the search bar.
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    // Always clean up controllers & timers to prevent memory leaks.
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  // ── Debounce handler ─────────────────────────────────────────────────────
  void _onSearchChanged() {
    // Cancel any previously scheduled query.
    _debounce?.cancel();

    // Schedule a new query 500 ms from now.
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(_searchController.text.trim());
    });
  }

  // ========================================================================
  // 5. SUPABASE QUERY — _performSearch()
  // ========================================================================
  // SUPABASE CONCEPT — Querying with the Dart client:
  //
  //   supabase.from('table_name')     → selects the table
  //           .select()               → like SQL SELECT *
  //           .ilike('column', '%q%') → case-insensitive LIKE
  //           .or('col1.ilike.%q%,col2.ilike.%q%')
  //                                   → combines conditions with OR
  //           .order('column')        → ORDER BY column ASC
  //
  //   The result is a List<Map<String, dynamic>> — each Map is a row,
  //   and each key is a column name.

  Future<void> _performSearch(String query) async {
    // If the search bar is empty, reset to the welcome state.
    if (query.isEmpty) {
      setState(() {
        _books = [];
        _hasSearched = false;
        _isLoading = false;
      });
      return;
    }

    // Show the loading spinner.
    setState(() {
      _isLoading = true;
    });

    try {
      // Build the ILIKE pattern for a partial, case-insensitive match.
      final pattern = '%$query%';

      // SUPABASE — .or() filter:
      //   The string inside .or() uses PostgREST filter syntax:
      //     column.operator.value
      //   Multiple conditions are separated by commas and combined with OR.
      final results = await supabase
          .from('Books')
          .select()
          .or('Title.ilike.$pattern,Author.ilike.$pattern,ISBN.ilike.$pattern')
          .order('Title', ascending: true);

      // `results` is already a List<Map<String, dynamic>> — no need to decode.
      setState(() {
        _books = List<Map<String, dynamic>>.from(results);
        _hasSearched = true;
        _isLoading = false;
      });
    } catch (error) {
      // On failure, clear results and show nothing (you could show a snackbar).
      setState(() {
        _books = [];
        _hasSearched = true;
        _isLoading = false;
      });

      // Show a brief error message at the bottom of the screen.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search failed: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  // ========================================================================
  // 6. ADD BOOK — _showAddBookSheet()
  // ========================================================================
  // Opens a modal bottom sheet with four text fields and a Save button.
  // On save, inserts a row into Supabase and refreshes the search results.

  void _showAddBookSheet() {
    // Controllers for each input field inside the bottom sheet.
    final titleCtrl = TextEditingController();
    final authorCtrl = TextEditingController();
    final editionCtrl = TextEditingController();
    final isbnCtrl = TextEditingController();

    // A GlobalKey<FormState> lets us call .validate() on the Form widget.
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,       // allows the sheet to expand beyond 50%
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        // We need a StatefulBuilder so we can show a local loading spinner
        // inside the bottom sheet without rebuilding the whole screen.
        bool isSaving = false;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              // Shift the sheet up when the keyboard appears so the fields
              // remain visible.
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // wrap content height
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Sheet header ──────────────────────────────────────
                      // Drag handle
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      Text(
                        'Add a New Book',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Input fields ──────────────────────────────────────
                      // FLUTTER CONCEPT — TextFormField:
                      //   Like TextField but integrates with Form & validation.
                      //   `validator:` returns null if valid, or an error string.
                      _buildFormField(titleCtrl, 'Title', Icons.book_outlined),
                      const SizedBox(height: 12),
                      _buildFormField(authorCtrl, 'Author', Icons.person_outline),
                      const SizedBox(height: 12),
                      _buildFormField(editionCtrl, 'Edition', Icons.layers_outlined),
                      const SizedBox(height: 12),
                      _buildFormField(isbnCtrl, 'ISBN', Icons.qr_code),
                      const SizedBox(height: 24),

                      // ── Save button ───────────────────────────────────────
                      FilledButton.icon(
                        onPressed: isSaving
                            ? null // disable button while saving
                            : () async {
                                // Validate all fields via the Form's key.
                                if (!formKey.currentState!.validate()) return;

                                setSheetState(() => isSaving = true);

                                // Capture context-dependent objects BEFORE the
                                // async gap so we don't use BuildContext after
                                // an `await` (a common Flutter lint).
                                final messenger = ScaffoldMessenger.of(context);
                                final primaryColor = Theme.of(context).colorScheme.primary;
                                final errorColor = Theme.of(context).colorScheme.error;
                                final navigator = Navigator.of(context);

                                try {
                                  // SUPABASE — .insert():
                                  //   Inserts a new row. The argument is a Map
                                  //   whose keys match your column names.
                                  await supabase.from('Books').insert({
                                    'Title': titleCtrl.text.trim(),
                                    'Author': authorCtrl.text.trim(),
                                    'Edition': editionCtrl.text.trim(),
                                    'ISBN': isbnCtrl.text.trim(),
                                  });

                                  // Close the bottom sheet.
                                  navigator.pop();

                                  // Refresh the current search results so the
                                  // new book appears if it matches the query.
                                  _performSearch(_searchController.text.trim());

                                  // Show a success confirmation.
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: const Text('Book added successfully!'),
                                      backgroundColor: primaryColor,
                                    ),
                                  );
                                } catch (error) {
                                  setSheetState(() => isSaving = false);
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to add book: $error'),
                                      backgroundColor: errorColor,
                                    ),
                                  );
                                }
                              },
                        icon: isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(isSaving ? 'Saving…' : 'Save Book'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Helper: builds a single TextFormField with an icon and required validation.
  Widget _buildFormField(
    TextEditingController controller,
    String label,
    IconData icon,
  ) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
      // Validation: all four fields are required.
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '$label is required';
        }
        return null; // null means "valid"
      },
    );
  }

  // ========================================================================
  // 7. BUILD — The widget tree for this screen
  // ========================================================================
  // FLUTTER CONCEPT — build():
  //   Called every time setState() is invoked (or the parent rebuilds this
  //   widget). Returns a tree of widgets that Flutter renders on screen.

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      // ── App Bar ──────────────────────────────────────────────────────────
      appBar: AppBar(
        title: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'The Library of Parliament',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Parliament of Sri Lanka',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        centerTitle: true,
        elevation: 0,
      ),

      // ── Body ─────────────────────────────────────────────────────────────
      body: Column(
        children: [
          // ── Search bar ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by title, author, or ISBN…',
                prefixIcon: const Icon(Icons.search),
                // Show a clear button when there is text in the field.
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          // _onSearchChanged will fire automatically via the listener
                        },
                      )
                    : null,
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // ── Content area (results / loading / welcome) ────────────────────
          Expanded(child: _buildContent(colorScheme)),
        ],
      ),

      // ── Floating Action Button — opens the Add Book sheet ────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddBookSheet,
        icon: const Icon(Icons.add),
        label: const Text('Add Book'),
      ),
    );
  }

  // ========================================================================
  // 8. CONTENT BUILDER — decides what to show in the main area
  // ========================================================================

  Widget _buildContent(ColorScheme colorScheme) {
    // A) Loading state — show a centered spinner.
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // B) Welcome state — no search performed yet.
    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_rounded,
                size: 80, color: colorScheme.primary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              'Search for a book…',
              style: TextStyle(
                fontSize: 18,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Type a title, author, or ISBN above',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      );
    }

    // C) Empty results — searched but found nothing.
    if (_books.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                size: 80, color: colorScheme.error.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              'No books found',
              style: TextStyle(
                fontSize: 18,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      );
    }

    // D) Results list.
    // FLUTTER CONCEPT — ListView.builder:
    //   Builds list items lazily (only those visible on screen), which is
    //   much more efficient than creating all items upfront.
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80), // 80 = FAB clearance
      itemCount: _books.length,
      itemBuilder: (context, index) {
        return _BookCard(book: _books[index]);
      },
    );
  }
}

// ============================================================================
// 9. BOOK CARD — _BookCard (StatelessWidget)
// ============================================================================
// A reusable card widget that displays one book's information.
// It is a StatelessWidget because it only receives data and renders it —
// it never changes its own state.

class _BookCard extends StatelessWidget {
  final Map<String, dynamic> book;

  const _BookCard({required this.book});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Read values from the map, defaulting to '—' if null.
    final String title = (book['Title'] ?? '—').toString();
    final String author = (book['Author'] ?? '—').toString();
    final String edition = (book['Edition'] ?? '—').toString();
    final String isbn = (book['ISBN'] ?? '—').toString();

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title row ─────────────────────────────────────────────
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),

            // ── Author ────────────────────────────────────────────────
            _infoRow(Icons.person_outline, 'Author', author, colorScheme),
            const SizedBox(height: 4),

            // ── Edition ───────────────────────────────────────────────
            _infoRow(Icons.layers_outlined, 'Edition', edition, colorScheme),
            const SizedBox(height: 4),

            // ── ISBN ──────────────────────────────────────────────────
            _infoRow(Icons.qr_code, 'ISBN', isbn, colorScheme),
          ],
        ),
      ),
    );
  }

  // Helper: a single info row with an icon, label, and value.
  Widget _infoRow(
    IconData icon,
    String label,
    String value,
    ColorScheme colorScheme,
  ) {
    return Row(
      children: [
        Icon(icon, size: 16, color: colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurface.withValues(alpha: 0.9),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
