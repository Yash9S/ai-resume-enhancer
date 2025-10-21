const App = (props) => {
  const { currentUser, currentView = 'dashboard' } = props;
    
  return (
      React.createElement('div', { className: 'app-container' },
        React.createElement(Navigation, { currentUser: currentUser }),
        React.createElement('main', { className: 'main-content' },
          React.createElement('div', { className: 'container' },
            currentView === 'dashboard' && React.createElement(Dashboard, { currentUser: currentUser })
          )
        )
      )
    );
};