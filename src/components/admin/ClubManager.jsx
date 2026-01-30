import { useState } from 'react';
import { useAdminClubs } from '../../hooks/useAdmin';

const categories = ['academic', 'professional', 'social', 'cultural', 'sports', 'other'];

/**
 * Club manager component for admins.
 * Allows adding, editing, and deleting clubs.
 */
export function ClubManager() {
  const { clubs, loading, addClub, updateClub, deleteClub } = useAdminClubs();
  const [showForm, setShowForm] = useState(false);
  const [editingClub, setEditingClub] = useState(null);
  const [formData, setFormData] = useState({
    name: '',
    description: '',
    category: 'other',
    website: '',
    image_url: '',
  });

  const resetForm = () => {
    setFormData({ name: '', description: '', category: 'other', website: '', image_url: '' });
    setEditingClub(null);
    setShowForm(false);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      if (editingClub) {
        await updateClub(editingClub.id, formData);
      } else {
        await addClub(formData);
      }
      resetForm();
    } catch (err) {
      console.error('Error saving club:', err);
    }
  };

  const handleEdit = (club) => {
    setFormData({
      name: club.name,
      description: club.description || '',
      category: club.category,
      website: club.website || '',
      image_url: club.image_url || '',
    });
    setEditingClub(club);
    setShowForm(true);
  };

  const handleDelete = async (id) => {
    if (window.confirm('Are you sure you want to delete this club?')) {
      await deleteClub(id);
    }
  };

  if (loading) {
    return <div className="text-center py-8">Loading clubs...</div>;
  }

  return (
    <div>
      <div className="flex justify-between items-center mb-6">
        <h2 className="text-xl font-bold text-gray-900">Manage Clubs ({clubs.length})</h2>
        <button
          onClick={() => setShowForm(true)}
          className="px-4 py-2 bg-berkeley-blue text-white rounded-lg hover:bg-berkeley-blue/90"
        >
          Add Club
        </button>
      </div>

      {showForm && (
        <div className="bg-gray-50 rounded-lg p-4 mb-6">
          <form onSubmit={handleSubmit} className="space-y-4">
            <input
              type="text"
              placeholder="Club name"
              value={formData.name}
              onChange={(e) => setFormData({ ...formData, name: e.target.value })}
              required
              className="w-full px-4 py-2 border rounded-lg"
            />
            <textarea
              placeholder="Description"
              value={formData.description}
              onChange={(e) => setFormData({ ...formData, description: e.target.value })}
              rows={3}
              className="w-full px-4 py-2 border rounded-lg"
            />
            <select
              value={formData.category}
              onChange={(e) => setFormData({ ...formData, category: e.target.value })}
              className="w-full px-4 py-2 border rounded-lg"
            >
              {categories.map((cat) => (
                <option key={cat} value={cat}>{cat}</option>
              ))}
            </select>
            <input
              type="url"
              placeholder="Website URL"
              value={formData.website}
              onChange={(e) => setFormData({ ...formData, website: e.target.value })}
              className="w-full px-4 py-2 border rounded-lg"
            />
            <input
              type="url"
              placeholder="Image URL"
              value={formData.image_url}
              onChange={(e) => setFormData({ ...formData, image_url: e.target.value })}
              className="w-full px-4 py-2 border rounded-lg"
            />
            <div className="flex gap-2">
              <button type="submit" className="px-4 py-2 bg-berkeley-blue text-white rounded-lg">
                {editingClub ? 'Update' : 'Add'} Club
              </button>
              <button type="button" onClick={resetForm} className="px-4 py-2 border rounded-lg">
                Cancel
              </button>
            </div>
          </form>
        </div>
      )}

      <div className="space-y-2">
        {clubs.map((club) => (
          <div key={club.id} className="flex items-center justify-between bg-white p-4 rounded-lg border">
            <div>
              <span className="font-medium">{club.name}</span>
              <span className="text-gray-500 text-sm ml-2">({club.category})</span>
              <span className="text-berkeley-blue text-sm ml-2">ELO: {club.elo_rating}</span>
            </div>
            <div className="flex gap-2">
              <button
                onClick={() => handleEdit(club)}
                className="px-3 py-1 text-sm border rounded hover:bg-gray-50"
              >
                Edit
              </button>
              <button
                onClick={() => handleDelete(club.id)}
                className="px-3 py-1 text-sm text-red-600 border border-red-200 rounded hover:bg-red-50"
              >
                Delete
              </button>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
