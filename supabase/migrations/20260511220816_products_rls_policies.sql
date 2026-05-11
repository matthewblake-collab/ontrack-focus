-- Restrict catalogue reads to authenticated users (no anonymous access)
drop policy if exists "products_select" on products;
create policy "products_select" on products
  for select using (auth.uid() is not null);

-- Allow authenticated users to insert user-contributed products only
create policy "products_user_insert" on products
  for insert with check (
    source = 'user' and contributed_by = auth.uid()
  );

-- Allow users to update their own contributed products only
create policy "products_user_update" on products
  for update using (
    source = 'user' and contributed_by = auth.uid()
  );
