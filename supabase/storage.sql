INSERT INTO storage.buckets(id,name,public) VALUES ('reports','reports',false) ON CONFLICT(id) DO NOTHING;
CREATE POLICY "own avatars update" ON storage.objects FOR UPDATE USING(bucket_id='avatars' AND owner=auth.uid());
CREATE POLICY "private documents read by owner" ON storage.objects FOR SELECT USING(bucket_id IN ('receipts','documents','reports') AND owner=auth.uid());
