import { useState, useEffect, useCallback } from 'react';
import { supabase } from './supabaseClient';
import { Search, Plus, User, Layers, Hash, BookOpen, X, LogOut } from 'lucide-react';
import './index.css';

// --- AUTHENTICATION COMPONENT ---
function Auth() {
  const [loading, setLoading] = useState(false);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [isLogin, setIsLogin] = useState(true);
  const [errorMsg, setErrorMsg] = useState('');
  const [successMsg, setSuccessMsg] = useState('');

  const handleAuth = async (e) => {
    e.preventDefault();
    setLoading(true);
    setErrorMsg('');
    setSuccessMsg('');

    try {
      if (isLogin) {
        const { error } = await supabase.auth.signInWithPassword({ email, password });
        if (error) throw error;
      } else {
        const { error } = await supabase.auth.signUp({ email, password });
        if (error) throw error;
        setSuccessMsg('Sign up successful! You can now log in.');
        setIsLogin(true);
      }
    } catch (error) {
      setErrorMsg(error.error_description || error.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="auth-wrapper">
      <div className="auth-card">
        <img src="/login-logo.png" alt="Parliament of Sri Lanka Logo" className="auth-logo-wide" />
        <h2>Library of Parliament</h2>
        <p>Restricted access. Please sign in.</p>

        {errorMsg && <div className="auth-error">{errorMsg}</div>}
        {successMsg && <div className="auth-message">{successMsg}</div>}

        <form className="auth-form" onSubmit={handleAuth}>
          <div className="form-group">
            <label>Email Address</label>
            <input
              type="email"
              className="form-control"
              placeholder="librarian@parliament.lk"
              value={email}
              required
              onChange={(e) => setEmail(e.target.value)}
            />
          </div>
          <div className="form-group">
            <label>Password</label>
            <input
              type="password"
              className="form-control"
              placeholder="••••••••"
              value={password}
              required
              onChange={(e) => setPassword(e.target.value)}
            />
          </div>
          <button className="btn-primary" type="submit" disabled={loading}>
            {loading ? 'Processing...' : (isLogin ? 'Sign In' : 'Sign Up')}
          </button>
        </form>

        <button 
          className="auth-toggle" 
          onClick={() => { setIsLogin(!isLogin); setErrorMsg(''); setSuccessMsg(''); }}
        >
          {isLogin ? "Don't have an account? Sign Up" : "Already have an account? Sign In"}
        </button>
      </div>
    </div>
  );
}

// --- MAIN APP COMPONENT ---
function App() {
  const [session, setSession] = useState(null);
  
  const [books, setBooks] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [searchFilter, setSearchFilter] = useState('All');
  const [isModalOpen, setIsModalOpen] = useState(false);

  const [formData, setFormData] = useState({
    Title: '',
    Author: '',
    Edition: '',
    ISBN: '',
  });

  // Auth Effect
  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session);
    });

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, session) => {
      setSession(session);
    });

    return () => subscription.unsubscribe();
  }, []);

  // Debounced search with abort guard
  useEffect(() => {
    if (!session) return;

    // If search is empty, clear immediately
    if (searchQuery.trim() === '') {
      setBooks([]);
      setLoading(false);
      return;
    }

    let cancelled = false;
    setLoading(true);

    const timerId = setTimeout(async () => {
      const pattern = `%${searchQuery.trim()}%`;
      let query = supabase.from('Books').select();

      if (searchFilter === 'All') {
        query = query.or(`Title.ilike.${pattern},Author.ilike.${pattern},ISBN.ilike.${pattern}`);
      } else {
        query = query.ilike(searchFilter, pattern);
      }

      const { data, error } = await query.order('Title', { ascending: true });

      // Only update state if this request wasn't cancelled
      if (!cancelled) {
        if (error) {
          console.error('Error fetching books:', error);
        } else {
          setBooks(data || []);
        }
        setLoading(false);
      }
    }, 500);

    return () => {
      cancelled = true;
      clearTimeout(timerId);
    };
  }, [searchQuery, searchFilter, session]);

  const handleAddBook = async (e) => {
    e.preventDefault();
    
    const newBook = {
      ...formData,
      Edition: parseInt(formData.Edition, 10) || null
    };

    const { error } = await supabase.from('Books').insert([newBook]);
    
    if (error) {
      alert('Error adding book: ' + error.message);
      console.error(error);
    } else {
      setIsModalOpen(false);
      setFormData({ Title: '', Author: '', Edition: '', ISBN: '' });
      // Trigger a re-fetch by bumping the search query
      setSearchQuery(prev => prev + ' ');
      setTimeout(() => setSearchQuery(searchQuery), 0);
    }
  };

  const handleSignOut = async () => {
    const { error } = await supabase.auth.signOut();
    if (error) console.error('Error signing out:', error.message);
  };

  // Render Auth if not logged in
  if (!session) {
    return <Auth />;
  }

  // Render App if logged in
  return (
    <>
      <header className="app-header">
        <div className="logo-container">
          <div className="logo-text">
            <h1>Library of Parliament</h1>
            <p>Parliament of Sri Lanka</p>
          </div>
        </div>
        <div className="header-actions">
          <button className="btn-primary add-book-btn" onClick={() => setIsModalOpen(true)}>
            <Plus size={20} />
            <span className="add-book-text">Add Book</span>
          </button>
          <button className="btn-secondary sign-out-btn" onClick={handleSignOut}>
            <LogOut size={18} />
            <span className="sign-out-text">Sign Out</span>
          </button>
        </div>
      </header>

      <main className="main-content">
        <div className="search-row">
          <select
            className="search-filter"
            value={searchFilter}
            onChange={(e) => setSearchFilter(e.target.value)}
          >
            <option value="All">All</option>
            <option value="Title">Title</option>
            <option value="Author">Author</option>
            <option value="ISBN">ISBN</option>
          </select>
          <div className="search-container">
            <Search className="search-icon" size={20} />
            <input 
              type="search" 
              className="search-input" 
              placeholder={searchFilter === 'All' ? 'Search by title, author, or ISBN...' : `Search by ${searchFilter.toLowerCase()}...`}
              value={searchQuery}
              autoComplete="one-time-code"
              onChange={(e) => {
                const val = e.target.value;
                setSearchQuery(val);
                if (val.trim() === '') setBooks([]);
              }}
            />
            {searchQuery && (
              <button
                className="search-clear-btn"
                onClick={() => window.location.reload()}
                aria-label="Clear search"
              >
                <X size={18} />
              </button>
            )}
          </div>
        </div>

        {searchQuery.trim() === '' ? (
          <div className="state-container">
            <Search size={48} className="text-muted" style={{ marginBottom: '1rem', opacity: 0.5 }} />
            <h3>Search for a book</h3>
            <p>Type a title, author, or ISBN to begin.</p>
          </div>
        ) : loading ? (
          <div className="state-container">
            <div className="spinner"></div>
            <p>Loading books...</p>
          </div>
        ) : books.length === 0 ? (
          <div className="state-container">
            <BookOpen size={48} className="text-muted" style={{ marginBottom: '1rem', opacity: 0.5 }} />
            <h3>No books found</h3>
            <p>Try adjusting your search query or add a new book.</p>
          </div>
        ) : (
          <div className="book-grid">
            {books.map((book, index) => (
              <div key={book.id || `${book.ISBN}-${index}`} className="book-card">
                <h3 className="book-title">{book.Title || '—'}</h3>
                
                <div className="book-detail">
                  <User className="book-detail-icon" />
                  <span><strong>Author:</strong> {book.Author || '—'}</span>
                </div>
                
                <div className="book-detail">
                  <Layers className="book-detail-icon" />
                  <span><strong>Edition:</strong> {book.Edition?.toString() || '—'}</span>
                </div>
                
                <div className="book-detail">
                  <Hash className="book-detail-icon" />
                  <span><strong>ISBN:</strong> {book.ISBN || '—'}</span>
                </div>
              </div>
            ))}
          </div>
        )}
      </main>

      {/* Add Book Modal */}
      {isModalOpen && (
        <div className="modal-overlay" onClick={() => setIsModalOpen(false)}>
          <div className="modal-content" onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h2 className="modal-title">Add New Book</h2>
              <button className="btn-close" onClick={() => setIsModalOpen(false)}>
                <X size={24} />
              </button>
            </div>
            
            <form onSubmit={handleAddBook}>
              <div className="form-group">
                <label>Title</label>
                <input 
                  type="text" 
                  className="form-control" 
                  required 
                  value={formData.Title}
                  onChange={e => setFormData({...formData, Title: e.target.value})}
                />
              </div>
              
              <div className="form-group">
                <label>Author</label>
                <input 
                  type="text" 
                  className="form-control" 
                  required 
                  value={formData.Author}
                  onChange={e => setFormData({...formData, Author: e.target.value})}
                />
              </div>
              
              <div className="form-group">
                <label>Edition (Number)</label>
                <input 
                  type="number" 
                  className="form-control" 
                  required 
                  value={formData.Edition}
                  onChange={e => setFormData({...formData, Edition: e.target.value})}
                />
              </div>
              
              <div className="form-group">
                <label>ISBN</label>
                <input 
                  type="text" 
                  className="form-control" 
                  required 
                  value={formData.ISBN}
                  onChange={e => setFormData({...formData, ISBN: e.target.value})}
                />
              </div>
              
              <div className="modal-footer">
                <button type="button" className="btn-secondary" onClick={() => setIsModalOpen(false)}>
                  Cancel
                </button>
                <button type="submit" className="btn-primary">
                  Save Book
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </>
  );
}

export default App;
