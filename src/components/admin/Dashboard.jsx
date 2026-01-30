import { useState } from 'react';
import { ClubManager } from './ClubManager';
import { CommentModerator } from './CommentModerator';
import { ReportViewer } from './ReportViewer';

/**
 * Admin dashboard component.
 * Provides tabs for different admin functions.
 * @param {{ onLogout: function }} props
 */
export function Dashboard({ onLogout }) {
  const [activeTab, setActiveTab] = useState('clubs');

  const tabs = [
    { id: 'clubs', label: 'Clubs' },
    { id: 'comments', label: 'Comments' },
    { id: 'reports', label: 'Reports' },
  ];

  return (
    <div className="max-w-4xl mx-auto px-4 py-8">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-2xl font-bold text-gray-900">Admin Dashboard</h1>
        <button
          onClick={onLogout}
          className="px-4 py-2 text-gray-600 hover:text-gray-900"
        >
          Sign Out
        </button>
      </div>

      <div className="flex gap-2 mb-6">
        {tabs.map((tab) => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id)}
            className={`px-4 py-2 rounded-lg font-medium transition-colors ${
              activeTab === tab.id
                ? 'bg-berkeley-blue text-white'
                : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>

      <div className="bg-white rounded-xl shadow-lg p-6">
        {activeTab === 'clubs' && <ClubManager />}
        {activeTab === 'comments' && <CommentModerator />}
        {activeTab === 'reports' && <ReportViewer />}
      </div>
    </div>
  );
}
