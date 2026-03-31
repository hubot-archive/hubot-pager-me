const globals = require('globals');

module.exports = [
  {
    ignores: ['node_modules/**', 'coverage/**'],
  },
  {
    files: ['src/**/*.js', 'index.js'],
    languageOptions: {
      ecmaVersion: 2020,
      sourceType: 'commonjs',
      globals: {
        ...globals.node,
      },
    },
    rules: {
      // Possible errors
      'no-undef': 'error',
      'no-unused-vars': ['error', { args: 'after-used', ignoreRestSiblings: true }],
      'no-console': ['warn', { allow: ['warn', 'error'] }],

      // Best practices
      'eqeqeq': ['error', 'always', { null: 'ignore' }],
      'no-eval': 'error',
      'no-implied-eval': 'error',
      'no-new-func': 'error',
      'no-return-assign': 'error',
      'no-throw-literal': 'error',
      'no-unused-expressions': ['error', { allowShortCircuit: true, allowTernary: true }],
      'prefer-const': ['error', { destructuring: 'all' }],

      // Style (aligned with .prettierrc)
      'no-var': 'error',
    },
  },
  {
    files: ['test/**/*.js'],
    languageOptions: {
      ecmaVersion: 2020,
      sourceType: 'commonjs',
      globals: {
        ...globals.node,
        ...globals.mocha,
      },
    },
    rules: {
      'no-undef': 'error',
      'no-unused-vars': ['error', { args: 'after-used', ignoreRestSiblings: true }],
      'no-console': 'off',
      'eqeqeq': ['error', 'always', { null: 'ignore' }],
      'no-eval': 'error',
      'no-unused-expressions': ['off'], // chai `expect(x).to.be.true` triggers this
      'prefer-const': ['error', { destructuring: 'all' }],
      'no-var': 'error',
    },
  },
];
