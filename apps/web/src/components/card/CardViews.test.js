// @vitest-environment happy-dom
import { afterEach, describe, expect, it, vi } from 'vitest'
import { createApp, h, ref, nextTick } from 'vue'
import CreditCardCardList from './CreditCardCardList.vue'
import CreditCardTable from '../table/CreditCardTable.vue'
const apps=[]
afterEach(() => { apps.splice(0).forEach(app => app.unmount()); document.body.innerHTML=''; localStorage.clear() })
const cards=Array.from({length: 2000}, (_, i) => ({ id:String(i),country:'US',bank:'BANK',cardNumber:'412345678901'+String(i).padStart(4,'0'),type:'USD',limit:100,cardCategory:'credit',isSharedLimit:true, isQualified:'3', valid:'2030-12' }))
const mount = (component, props) => {
  const target=document.createElement('div');document.body.append(target)
  const app=createApp({ render:()=>h(component,props) });apps.push(app)
  const errors=[];app.config.errorHandler=e=>errors.push(e.message)
  app.provide('calendarDay', ref(Date.now()));app.mount(target)
  return {target,errors}
}
describe('bounded real Vue component rendering', () => {
  it('mounts at most 24 physical cards for 2000 records', async () => {
    const {target, errors}=mount(CreditCardCardList,{tableData:cards,selectedRows:[]})
    await nextTick();await nextTick()
    expect(errors).toEqual([])
    expect(target.querySelectorAll('.physics-card-wrapper')).toHaveLength(24)
    expect(target.textContent).toContain('2000张')
  })
  it('mounts at most 50 table rows and keeps stable identifiers', async () => {
    const {target, errors}=mount(CreditCardTable,{tableData:cards,selectedRows:[],visibleColumns:['bank','cardNumber','limit']})
    await nextTick();await nextTick()
    expect(errors).toEqual([])
    expect(target.querySelectorAll('.el-table__body tr')).toHaveLength(50)
  })
})
