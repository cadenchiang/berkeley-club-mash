import { useAdmin } from '../hooks/useAdmin';
import { AdminLogin } from '../components/admin/AdminLogin';
import { Dashboard } from '../components/admin/Dashboard';

/**
 * Admin page component.
 * Shows login or dashboard based on auth state.
 */
export function Admin() {
  const { user, isAdmin, loading, signIn, signOut } = useAdmin();

  if (loading) {
    return (
      <div className="flex justify-center items-center py-20">
        <div className="animate-spin rounded-full h-12 w-12 border-4 border-berkeley-blue border-t-transparent"></div>
      </div>
    );
  }

  if (!user) {
    return <AdminLogin onLogin={signIn} />;
  }

  if (!isAdmin) {
    return (
      <div className="max-w-md mx-auto px-4 py-12 text-center">
        <h1 className="text-2xl font-bold text-gray-900 mb-4">Access Denied</h1>
        <p className="text-gray-600 mb-6">
          Your account does not have admin privileges.
        </p>
        <button
          onClick={signOut}
          className="px-4 py-2 bg-gray-200 rounded-lg hover:bg-gray-300"
        >
          Sign Out
        </button>
      </div>
    );
  }

  return <Dashboard onLogout={signOut} />;
}
