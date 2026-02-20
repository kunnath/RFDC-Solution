import React from 'react';

class ErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }

  componentDidCatch(error, info) {
    // Log to console so developer can inspect stack in browser/devtools
    // (keep this lightweight; real apps would report to telemetry)
    // eslint-disable-next-line no-console
    console.error('ErrorBoundary caught an error', error, info);
  }

  render() {
    if (this.state.hasError) {
      return (
        <div style={{ padding: 12, color: '#b91c1c' }}>
          <strong>Rendering error:</strong>
          <div style={{ marginTop: 8 }}>{this.state.error?.message || 'Unknown error'}</div>
          <div style={{ marginTop: 8, color: '#64748b' }}>Try refreshing the Tests browser.</div>
        </div>
      );
    }
    return this.props.children;
  }
}

export default ErrorBoundary;
