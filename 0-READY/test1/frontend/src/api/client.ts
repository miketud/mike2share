import axios, { AxiosInstance } from 'axios'

let client: AxiosInstance | null = null

export function getApi(): AxiosInstance {
  if (client) return client

  const baseURL = process.env.NEXT_PUBLIC_API_URL
  if (!baseURL) {
    throw new Error('NEXT_PUBLIC_API_URL not defined')
  }

  client = axios.create({
    baseURL,
    timeout: 10000,
    headers: {
      'Content-Type': 'application/json',
    },
  })

  client.interceptors.response.use(
    (response) => response,
    (error) => {
      if (error.response) {
        return Promise.reject({
          status: error.response.status,
          data: error.response.data,
        })
      }
      return Promise.reject({
        message: error.message,
      })
    }
  )

  return client
}
