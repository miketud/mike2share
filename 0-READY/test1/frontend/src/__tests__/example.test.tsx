import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import Home from '@/app/page';

test('renders landing page', () => {
  render(<Home />);
  expect(screen.getByText(/Next.js\/TypeScript \+ Python Bootstrap/i)).toBeInTheDocument();
});
