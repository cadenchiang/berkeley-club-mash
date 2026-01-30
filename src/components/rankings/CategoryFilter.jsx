const categories = [
  { value: 'all', label: 'All' },
  { value: 'tech', label: 'Tech' },
  { value: 'consulting', label: 'Consulting' },
  { value: 'finance', label: 'Finance' },
  { value: 'cultural', label: 'Cultural' },
  { value: 'social', label: 'Social' },
];

/**
 * Category filter component.
 * Allows filtering clubs by category.
 * @param {{ value: string, onChange: function }} props
 */
export function CategoryFilter({ value, onChange }) {
  return (
    <div className="flex flex-wrap gap-2">
      {categories.map((cat) => (
        <button
          key={cat.value}
          onClick={() => onChange(cat.value)}
          className={`
            px-4 py-2 rounded-full text-sm font-medium transition-colors
            ${value === cat.value
              ? 'bg-berkeley-blue text-white'
              : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
            }
          `}
        >
          {cat.label}
        </button>
      ))}
    </div>
  );
}
