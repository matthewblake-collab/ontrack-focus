create policy "products_user_delete" on products
  for delete using (
    source = 'user' and contributed_by = auth.uid()
  );
