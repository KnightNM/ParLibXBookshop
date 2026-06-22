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
        <img src="/logo.png" alt="Library Logo" className="auth-logo" />
        <h2>The Library of Parliament</h2>
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

  const fetchBooks = useCallback(async (query = '') => {
    if (!session) return;
    
    if (query.trim() === '') {
      setBooks([]);
      setLoading(false);
      return;
    }

    setLoading(true);
    let req = supabase.from('Books').select();

    const pattern = `%${query.trim()}%`;
    req = req.or(`Title.ilike.${pattern},Author.ilike.${pattern},ISBN.ilike.${pattern}`);

    req = req.order('Title', { ascending: true });

    const { data, error } = await req;
    
    if (error) {
      console.error('Error fetching books:', error);
    } else {
      setBooks(data || []);
    }
    setLoading(false);
  }, [session]);

  // Debounced search
  useEffect(() => {
    const timerId = setTimeout(() => {
      if (session) fetchBooks(searchQuery);
    }, 500);

    return () => clearTimeout(timerId);
  }, [searchQuery, fetchBooks, session]);

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
      fetchBooks(searchQuery);
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
          <img src="/logo.png" alt="Library Logo" className="logo-image" />
          <div className="logo-text">
            <h1>The Library of Parliament</h1>
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
        <div className="search-container">
          <Search className="search-icon" size={20} />
          <input 
            type="text" 
            className="search-input" 
            placeholder="Search by title, author, or ISBN..." 
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
          />
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
            {books.map((book) => (
              <div key={book.id || book.ISBN || Math.random()} className="book-card">
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
