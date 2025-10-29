const App = (props) => {
  const { currentUser, currentView = 'dashboard' } = props;
    
  return (
    <div className="app-container">
      <Navigation currentUser={currentUser} />
      <main className="main-content">
        <div className="container">
          {currentView === 'dashboard' && <Dashboard currentUser={currentUser} />}
        </div>
      </main>
    </div>
  );
};