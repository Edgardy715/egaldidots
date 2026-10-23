import bisect,collections,gzip,json,re
from pathlib import Path
out=Path(__file__).resolve().parent
info=json.loads((out/'profiler-index.json').read_text());events=info['events']
marks=json.loads((out/'profiler-marks.json').read_text())
rows=json.loads((out/'memory-profile-complete-batches.json').read_text());assert len(rows)==len(marks)
mem=[collections.Counter() for _ in marks];pix=[{} for _ in marks]
range_pattern=re.compile(r'<range (.*?)/>')
attributes=re.compile(r'(\w+)="([^"]*)"')
for line in gzip.open(out/'memory-profile-complete.qtd.gz', 'rt'):
 if 'amount=' not in line and 'refCount=' not in line and 'width=' not in line:continue
 m=range_pattern.search(line)
 if not m:continue
 a=dict(attributes.findall(m[1]));event=events[a['eventIndex']];stamp=int(a['startTime']);slot=bisect.bisect_left(marks,stamp)
 if slot==len(marks):continue
 if event['type']=='MemoryAllocation':mem[slot][event['memoryEventType']]+=int(a['amount'])
 elif event['type']=='PixmapCache':
  key=(event.get('filename',''),event['cacheEventType'])
  for states in pix[slot:]:
   if stamp>=states.get(key,(-1,{}))[0]:states[key]=(stamp,a)
cumulative=collections.Counter();result=[]
for i,row in enumerate(rows):
 cumulative.update(mem[i]);sizes={url:int(a.get('width',0))*int(a.get('height',0))*4 for (url,kind),(stamp,a) in pix[i].items() if kind=='0'}
 caches={url:int(a.get('refCount',0)) for (url,kind),(stamp,a) in pix[i].items() if kind=='2'}
 refs={url:int(a.get('refCount',0)) for (url,kind),(stamp,a) in pix[i].items() if kind=='1'}
 row.update(heap_pages_bytes=cumulative['0'],large_items_bytes=cumulative['1'],regular_items_bytes=cumulative['2'],pixmap_cached_entries=sum(v>0 for v in caches.values()),pixmap_referenced_entries=sum(v>0 for v in refs.values()),pixmap_known_rgba_bytes=sum(sizes.values()))
 result.append(row)
print(json.dumps(result,indent=2))
(out/'memory-profile-summary.json').write_text(json.dumps(result,indent=2)+'\n')
