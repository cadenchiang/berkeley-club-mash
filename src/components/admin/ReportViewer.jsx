import { useAdminReports, useAdminComments } from '../../hooks/useAdmin';

/**
 * Report viewer component for admins.
 * Displays reported comments and allows status updates.
 */
export function ReportViewer() {
  const { reports, loading, updateStatus } = useAdminReports();
  const { hideComment } = useAdminComments();

  const handleHideAndResolve = async (report) => {
    await hideComment(report.comment_id);
    await updateStatus(report.id, 'reviewed');
  };

  if (loading) {
    return <div className="text-center py-8">Loading reports...</div>;
  }

  const pendingReports = reports.filter((r) => r.status === 'pending');
  const resolvedReports = reports.filter((r) => r.status !== 'pending');

  return (
    <div>
      <h2 className="text-xl font-bold text-gray-900 mb-6">
        Reports ({pendingReports.length} pending)
      </h2>

      {pendingReports.length === 0 ? (
        <p className="text-gray-500 text-center py-8">No pending reports.</p>
      ) : (
        <div className="space-y-4 mb-8">
          {pendingReports.map((report) => (
            <div key={report.id} className="bg-white p-4 rounded-lg border border-orange-200">
              <div className="flex justify-between items-start mb-2">
                <span className="text-sm text-gray-500">
                  Club: {report.comments?.clubs?.name || 'Unknown'}
                </span>
                <span className="text-xs px-2 py-1 rounded bg-orange-100 text-orange-800">
                  Pending
                </span>
              </div>

              <div className="bg-gray-50 p-3 rounded mb-3">
                <p className="text-sm text-gray-600 mb-1">Reported comment:</p>
                <p className="text-gray-800">{report.comments?.content || 'Comment deleted'}</p>
              </div>

              <p className="text-sm mb-3">
                <span className="font-medium">Reason:</span> {report.reason}
              </p>

              <div className="flex gap-2">
                <button
                  onClick={() => handleHideAndResolve(report)}
                  className="px-3 py-1 bg-red-600 text-white text-sm rounded hover:bg-red-700"
                >
                  Hide Comment & Resolve
                </button>
                <button
                  onClick={() => updateStatus(report.id, 'dismissed')}
                  className="px-3 py-1 border text-sm rounded hover:bg-gray-50"
                >
                  Dismiss
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {resolvedReports.length > 0 && (
        <>
          <h3 className="text-lg font-semibold text-gray-700 mb-4">Resolved Reports</h3>
          <div className="space-y-2">
            {resolvedReports.slice(0, 10).map((report) => (
              <div key={report.id} className="bg-gray-50 p-3 rounded text-sm">
                <span className={`px-2 py-1 rounded mr-2 ${
                  report.status === 'reviewed' ? 'bg-green-100 text-green-800' : 'bg-gray-200 text-gray-600'
                }`}>
                  {report.status}
                </span>
                {report.reason.substring(0, 50)}...
              </div>
            ))}
          </div>
        </>
      )}
    </div>
  );
}
