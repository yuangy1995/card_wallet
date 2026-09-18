// @vitest-environment happy-dom
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { effectScope, ref, nextTick } from 'vue'
const store=vi.hoisted(()=>({value:['a'], get:vi.fn(), set:vi.fn()}))
vi.mock('../utils/indexedDbStorage',()=>({localDataStore:{isUnlocked:true,get:()=>store.value,set:(...args)=>store.set(...args)}}))
import { useLocalFavorites } from './useLocalFavorites'
beforeEach(()=>{store.value=['a'];store.set.mockReset().mockImplementation(async(_,ids)=>{store.value=ids})})
describe('encrypted favorite persistence lifecycle',()=>{
 it('does not prune during initial empty hydration, then prunes against full committed data',async()=>{
   const scope=effectScope();const cards=ref([]);const ready=ref(false)
   const api=scope.run(()=>useLocalFavorites(cards,ready))
   await nextTick();expect(store.set).not.toHaveBeenCalled()
   cards.value=[{id:'a'},{id:'b'}];ready.value=true;await nextTick();await api.toggleFavorite('b')
   expect(api.favoriteIDs.value.has('a')).toBe(true);expect(api.favoriteIDs.value.has('b')).toBe(true)
   scope.stop();expect(api.favoriteIDs.value.size).toBe(0)
 })
 it('serializes fast toggles and does not report a failed save as successful',async()=>{
   const scope=effectScope();const error=vi.fn()
   const api=scope.run(()=>useLocalFavorites(ref([{id:'a'},{id:'b'},{id:'c'}]),ref(false),error))
   await Promise.all([api.toggleFavorite('b'),api.toggleFavorite('c')]);expect([...api.favoriteIDs.value]).toEqual(['a','b','c'])
   store.set.mockRejectedValueOnce(new Error('disk full'));await api.toggleFavorite('a')
   expect(api.favoriteIDs.value.has('a')).toBe(true);expect(error).toHaveBeenCalledOnce();scope.stop()
 })
})
